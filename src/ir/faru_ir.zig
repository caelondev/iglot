const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const typed_ast = @import("../sema/typed_ast.zig");
const ast = @import("../parser/ast.zig");
const tt = @import("../sema/type_table.zig");

const b_lit = @import("expressions/build_literals.zig");
const buildBinaryExpr = @import("expressions/build_binary_expr.zig").buildBinaryExpr;
const buildVariableDecl = @import("expressions/build_variable_decl.zig").buildVariableDecl;
const buildAssignmentExpr = @import("expressions/build_assignment_expr.zig").buildAssignmentExpr;
const buildUnaryExpr = @import("expressions/build_unary_expr.zig").buildUnaryExpr;

const buildFunction = @import("statements/build_function_decl.zig").buildFunction;
const buildReturn = @import("statements/build_return_stmt.zig").buildReturn;
const buildIfStatement = @import("statements/build_if_stmt.zig").buildIfStatement;
const buildCallExpr = @import("expressions/build_call_expr.zig").buildCallExpr;

pub const FaruIR = struct {
    module: Module,
    current_fn: *Function = undefined,
    current_block: *BasicBlock = undefined,
    locals: std.StringHashMapUnmanaged(inst.ValueRef),
    globals: std.StringHashMapUnmanaged(inst.GlobalRef),
    functions: std.StringHashMapUnmanaged(inst.FunctionRef),

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .locals = .empty,
            .globals = .empty,
            .functions = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.module.deinit(allocator);
        self.functions.deinit(allocator);
        self.locals.deinit(allocator);
        self.globals.deinit(allocator);
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, program: typed_ast.TypedProgram) !void {
        try self.initBuiltinGlobals(allocator);

        for (program.body) |stmt| {
            try self.buildTopLevelStmt(allocator, stmt);
        }
    }

    fn initBuiltinGlobals(self: *Self, allocator: std.mem.Allocator) !void {
        const true_ref = try self.module.addGlobal(allocator, .{
            .name = "true",
            .sema_type = .bool,
            .initializer = .{ .bool = true },
        });

        const false_ref = try self.module.addGlobal(allocator, .{
            .name = "false",
            .sema_type = .bool,
            .initializer = .{ .bool = false },
        });

        try self.globals.put(allocator, "true", true_ref);
        try self.globals.put(allocator, "false", false_ref);
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !void {
        switch (stmt) {
            .function_decl => |f| try buildFunction(self, allocator, f),
            .expression => |e| {
                switch (e.typed.kind) {
                    .variable_declaration => |v| try self.buildGlobalVariableDecl(allocator, e.typed.sem_type, v),
                    else => unreachable,
                }
            },
            else => unreachable,
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) anyerror!void {
        switch (stmt) {
            .return_stmt => |r| try buildReturn(self, allocator, r),
            .expression => |e| _ = try self.buildExpr(allocator, e.typed.*),
            .block => |b| {
                for (b.typed_stmts) |s| {
                    try self.buildStmt(allocator, s);
                }
            },
            .scoped => |s| {
                for (s.typed_stmts) |st| {
                    try self.buildStmt(allocator, st);
                }
            },
            .if_stmt => |i| try buildIfStatement(self, allocator, i),
            else => unreachable,
        }
    }

    pub fn buildExpr(self: *Self, allocator: std.mem.Allocator, expr: typed_ast.TypedExpr) anyerror!inst.ValueRef {
        return switch (expr.kind) {
            .integer => |i| try b_lit.buildInteger(self, allocator, expr.sem_type, i),
            .binary => |b| try buildBinaryExpr(self, allocator, expr.sem_type, b),
            .variable_declaration => |v| try buildVariableDecl(self, allocator, expr.sem_type, v),
            .identifier => |i| blk: {
                if (self.locals.get(i.value)) |slot| {
                    break :blk try self.emitLoad(allocator, slot, expr.sem_type);
                }

                if (self.globals.get(i.value)) |global_ref| {
                    const dest = self.current_fn.newValue();
                    try self.emit(allocator, .{
                        .op = .load_global,
                        .sema_type = expr.sem_type,
                        .result = dest,
                        .operands = &.{},
                        .data = .{ .global = global_ref },
                    });
                    break :blk dest;
                }

                const function_ref = self.functions.get(i.value) orelse unreachable; // sema guarantees availability
                const dest = self.current_fn.newValue();
                try self.emit(allocator, .{
                    .op = .const_fn,
                    .sema_type = expr.sem_type,
                    .result = dest,
                    .operands = &.{},
                    .data = .{ .constant = .{ .func = function_ref } },
                });
                break :blk dest;
            },
            .assignment => |a| try buildAssignmentExpr(self, allocator, expr.sem_type, a),
            .unary => |u| try buildUnaryExpr(self, allocator, expr.sem_type, u),
            .call => |c| try buildCallExpr(self, allocator, expr.sem_type, c),
            else => @panic("TODO: expr kind not implemented yet"),
        };
    }

    fn emitLoad(self: *Self, allocator: std.mem.Allocator, ptr: inst.ValueRef, sema_type: tt.SemaType) !inst.ValueRef {
        const dest = self.current_fn.newValue();
        try self.emit(allocator, .{
            .op = .load,
            .sema_type = sema_type,
            .result = dest,
            .operands = try allocator.dupe(inst.ValueRef, &.{ptr}),
            .data = .none,
        });
        return dest;
    }

    fn buildGlobalVariableDecl(
        self: *Self,
        allocator: std.mem.Allocator,
        sema_type: tt.SemaType,
        v: typed_ast.TypedVariableDeclaration,
    ) !void {
        const const_val = try self.evalConstant(v.value.*);

        const global_ref = try self.module.addGlobal(allocator, .{
            .name = v.identifier.value,
            .sema_type = sema_type,
            .initializer = const_val,
        });

        try self.globals.put(allocator, v.identifier.value, global_ref);
    }

    fn evalConstant(self: *Self, expr: typed_ast.TypedExpr) !inst.ConstantValue {
        _ = self;
        return switch (expr.kind) {
            .integer => |i| switch (expr.sem_type) {
                .wideint => .{ .wideint = i.value },
                .int => .{ .int = @intCast(i.value) },
                else => unreachable,
            },
            .wide_integer => |i| .{ .wideint = i.value },
            .float => |f| switch (expr.sem_type) {
                .float => .{ .float = @floatCast(f.value) },
                .double => .{ .double = f.value },
                else => unreachable,
            },
            .string => |s| .{ .string = s.value },
            else => @panic("TODO: non-constant global initializer"),
        };
    }

    pub fn buildPlace(self: *Self, expr: typed_ast.TypedExpr) !inst.Place {
        return switch (expr.kind) {
            .identifier => |i| blk: {
                if (self.locals.get(i.value)) |slot| {
                    break :blk .{ .local = slot };
                }

                const global_ref = self.globals.get(i.value) orelse unreachable;
                break :blk .{ .global = global_ref };
            },
            else => @panic("TODO: non-identifier assignment target"),
        };
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.append(allocator, instruction);
    }

    pub fn goToBlock(self: *Self, block: *BasicBlock) void {
        self.current_block = block;
    }
};
