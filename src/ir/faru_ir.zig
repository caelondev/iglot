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

pub const FaruIR = struct {
    module: Module,
    current_fn: *Function = undefined,
    current_block: *BasicBlock = undefined,
    locals: std.StringHashMap(inst.ValueRef),
    globals: std.StringHashMap(inst.GlobalRef),

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .locals = undefined,
            .globals = undefined,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.module.deinit(allocator);
        self.locals.deinit();
        self.globals.deinit();
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, program: typed_ast.TypedProgram) !void {
        self.locals = .init(allocator);
        self.globals = .init(allocator);

        for (program.body) |stmt| {
            try self.buildTopLevelStmt(allocator, stmt);
        }
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !void {
        switch (stmt) {
            .function_decl => |f| try self.buildFunction(allocator, f),
            .expression => |e| {
                switch (e.typed.kind) {
                    .variable_declaration => |v| try self.buildGlobalVariableDecl(allocator, e.typed.sem_type, v),
                    else => unreachable,
                }
            },
            else => unreachable,
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !void {
        switch (stmt) {
            .return_stmt => |r| try self.buildReturn(allocator, r),
            .expression => |e| _ = try self.buildExpr(allocator, e.typed.*),
            .block => |b| {
                for (b.typed_stmts) |s| {
                    try self.buildStmt(allocator, s);
                }
            },
            .function_decl => unreachable,
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

                const global_ref = self.globals.get(i.value) orelse unreachable; // sema guarantees availability

                const dest = self.current_fn.newValue();
                try self.emit(allocator, .{
                    .op = .load_global,
                    .sema_type = expr.sem_type,
                    .result = dest,
                    .operands = &.{},
                    .data = .{ .global = global_ref },
                });

                break :blk dest;
            },
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

    pub fn buildFunction(self: *Self, allocator: std.mem.Allocator, decl: typed_ast.TypedFunctionDeclarationStatement) !void {
        const params = try allocator.alloc(Function.Param, decl.parameters.len);
        for (decl.parameters, 0..) |p, i| {
            params[i] = .{ .name = p.identifier.value, .sema_type = p.param_type };
        }

        const function = Function.init(decl.identifier.value, params, decl.return_type);
        try self.module.functions.append(allocator, function);

        self.current_fn = self.module.currentFunction();

        const entry = try self.current_fn.newBlock(allocator, "entry");
        self.current_block = self.current_fn.getBlock(entry.id);

        self.locals.clearRetainingCapacity();

        for (decl.parameters, 0..) |p, i| {
            const param_val = self.current_fn.newValue();
            try self.emit(allocator, .{
                .op = .param,
                .sema_type = p.param_type,
                .operands = &.{},
                .result = param_val,
                .data = .{ .index = i },
            });

            const slot = self.current_fn.newValue();
            try self.emit(allocator, .{
                .op = .alloca,
                .sema_type = p.param_type,
                .operands = &.{},
                .result = slot,
                .data = .none,
            });

            try self.emit(allocator, .{
                .op = .store,
                .sema_type = p.param_type,
                .operands = try allocator.dupe(inst.ValueRef, &.{ slot, param_val }),
                .result = null,
                .data = .none,
            });

            try self.locals.put(p.identifier.value, slot);
        }

        try self.buildStmt(allocator, .{ .block = decl.body });

        if (self.current_block.isTerminated()) return;

        if (decl.return_type == .void) {
            try self.emit(allocator, .{
                .op = .ret_void,
                .sema_type = null,
                .result = null,
                .operands = &.{},
                .data = .none,
            });
        } else {
            try self.emit(allocator, .{
                .op = .@"unreachable",
                .sema_type = null,
                .result = null,
                .operands = &.{},
                .data = .none,
            });
        }
    }

    fn buildReturn(self: *Self, allocator: std.mem.Allocator, r: typed_ast.TypedReturnStatement) !void {
        if (r.return_value == null) {
            try self.emit(allocator, .{
                .op = .ret_void,
                .sema_type = null,
                .result = null,
                .operands = &.{},
                .data = .none,
            });
            return;
        }

        const val_expr = r.return_value orelse unreachable;
        const value = try self.buildExpr(allocator, val_expr.*);

        try self.emit(allocator, .{
            .op = .ret,
            .sema_type = r.return_value_type,
            .result = null,
            .operands = try allocator.dupe(inst.ValueRef, &.{value}),
            .data = .none,
        });
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

        try self.globals.put(v.identifier.value, global_ref);
    }

    fn evalConstant(self: *Self, expr: typed_ast.TypedExpr) !inst.ConstantValue {
        _ = self;
        return switch (expr.kind) {
            .integer => |i| .{ .int = @intCast(i.value) },
            else => @panic("TODO: non-constant global initializer"),
        };
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.append(allocator, instruction);
    }
};
