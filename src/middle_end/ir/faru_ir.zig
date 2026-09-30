const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const ScopeStack = @import("scope_table.zig").ScopeStack;
const inst = @import("instruction.zig");
const typed_ast = @import("../../frontend/sema/typed_ast.zig");
const ast = @import("../../frontend/parser/ast.zig");
const tt = @import("../../frontend/sema/type_table.zig");

const buildFunctionDecl = @import("statements/function_decl.zig").buildFunctionDecl;
const buildReturnStmt = @import("statements/return.zig").buildReturnStmt;
const buildVariableDecl = @import("statements/variable_decl.zig").buildVariableDecl;

const lit = @import("expressions/literal.zig");
const buildUnaryExpr = @import("expressions/unary.zig").buildUnaryExpr;
const buildBinaryExpr = @import("expressions/binary.zig").buildBinaryExpr;
const buildAssignmentExpr = @import("expressions/assignment.zig").buildAssignmentExpr;

pub const FaruIR = struct {
    module: Module,

    current_fn: *Function,
    current_block: *BasicBlock,
    current_scope: *ScopeStack,

    global_symtab: std.StringHashMapUnmanaged(inst.GlobalRef),

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),

            .current_scope = undefined,
            .current_fn = undefined,
            .current_block = undefined,

            .global_symtab = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.global_symtab.deinit(allocator);
        self.current_scope.deinit(allocator);
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, t_ast: typed_ast.TypedProgram) !void {
        const scope_stack = try allocator.create(ScopeStack);
        scope_stack.* = .init();
        self.current_scope = scope_stack;

        const init_fn = try self.module.createFunction(allocator, "@$__global_init", .void);
        const entry_bb = try init_fn.newBlock(allocator, "entry");
        self.current_fn = init_fn;
        self.goToBlock(entry_bb);

        try self.initFaruBuiltins(allocator);

        for (t_ast.body) |stmt| {
            try self.buildTopLevelStmt(allocator, stmt) orelse continue;
        }

        if (!self.current_block.isTerminated()) {
            try self.emit(allocator, .{
                .op = .ret_void,
                .sema_type = .void,
                .data = .none,
                .operands = &.{},
                .result = null,
            });
        }
    }

    pub fn initFaruBuiltins(self: *Self, allocator: std.mem.Allocator) !void {
        try self.buildBuiltinGlobal(allocator, "true", .bool, .{ .op = .const_bool, .const_data = .{ .bool = true } });
        try self.buildBuiltinGlobal(allocator, "false", .bool, .{ .op = .const_bool, .const_data = .{ .bool = false } });
    }

    fn buildBuiltinGlobal(self: *Self, allocator: std.mem.Allocator, global_name: []const u8, sema_type: tt.SemaType, lit_instr: struct { op: inst.Opcode, const_data: inst.ConstantValue }) !void {
        const ref = try self.addGlobal(allocator, global_name, sema_type);
        const dest = self.current_fn.newVReg();
        try self.emit(allocator, .{
            .op = lit_instr.op,
            .data = .{ .constant = lit_instr.const_data },
            .operands = &.{},
            .sema_type = sema_type,
            .result = dest,
        });
        try self.emit(allocator, .{
            .op = .store_global,
            .data = .{ .global = ref },
            .operands = try allocator.dupe(inst.VReg, &.{dest}),
            .sema_type = sema_type,
            .result = null,
        });
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .function_decl => |*f| try buildFunctionDecl(self, allocator, f) orelse return null,
            .variable_declaration => |*v| {
                const ref = try self.addGlobal(allocator, v.identifier.value, v.sema_type);
                const value_reg = try self.buildExpression(allocator, &v.value.*) orelse unreachable;
                try self.emit(allocator, .{
                    .op = .store_global,
                    .data = .{ .global = ref },
                    .operands = try allocator.dupe(inst.VReg, &.{value_reg}),
                    .sema_type = v.sema_type,
                    .result = null,
                });
            },

            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "illegal top level stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .return_stmt => |*r| try buildReturnStmt(self, allocator, r) orelse return null,
            .expression => |*e| _ = try self.buildExpression(allocator, e.typed),
            .variable_declaration => |*v| try buildVariableDecl(self, allocator, v) orelse return null,

            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "TODO: build stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildExpression(self: *Self, allocator: std.mem.Allocator, expr: *const typed_ast.TypedExpr) anyerror!?inst.VReg {
        const sema_type = expr.sem_type;

        return switch (expr.kind) {
            .integer => |*i| try lit.buildIntegerLit(self, allocator, i, sema_type),
            .wide_integer => |*i| try lit.buildWideIntegerLit(self, allocator, i, sema_type),
            .float => |*f| try lit.buildFloatLit(self, allocator, f, sema_type),
            .string => |*s| try lit.buildStringLit(self, allocator, s, sema_type),
            .assignment => |*a| try buildAssignmentExpr(self, allocator, a),
            .identifier => |*i| try self.resolveIdentifier(allocator, i, sema_type),

            .unary => |*u| try buildUnaryExpr(self, allocator, u),
            .binary => |*b| try buildBinaryExpr(self, allocator, b),

            else => |e| {
                const msg = try std.fmt.allocPrint(allocator, "TODO: build expr {s}", .{@tagName(e)});
                @panic(msg);
            },
        };
    }

    pub fn buildBodyStmt(self: *Self, allocator: std.mem.Allocator, block: typed_ast.TypedBlockStatement) !?void {
        for (block.typed_stmts) |stmt| {
            try self.buildStmt(allocator, stmt) orelse return null;
        }
    }

    pub fn resolveIdentifier(self: *Self, allocator: std.mem.Allocator, i: *const typed_ast.TypedIdentifier, sema_type: tt.SemaType) !?inst.VReg {
        if (self.current_scope.resolve(i.value)) |reg| {
            return reg;
        }

        if (self.global_symtab.get(i.value)) |ref| {
            const dest = self.current_fn.newVReg();

            try self.emit(allocator, .{
                .data = .{ .global = ref },
                .op = .load_global,
                .operands = &.{},
                .sema_type = sema_type,
                .result = dest,
            });
            return dest;
        }

        const func = self.module.getFunctionByName(i.value) orelse unreachable;
        const dest = self.current_fn.newVReg();

        try self.emit(allocator, .{
            .data = .{ .constant = .{ .func = func.function_ref } },
            .op = .load_fn,
            .operands = &.{},
            .sema_type = sema_type,
            .result = dest,
        });
        return dest;
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.instructions.append(allocator, instruction);
    }

    pub fn addGlobal(self: *Self, allocator: std.mem.Allocator, global_name: []const u8, sema_type: tt.SemaType) !inst.GlobalRef {
        const id: u32 = @intCast(self.module.globals.items.len);
        try self.module.globals.append(allocator, .{ .name = global_name, .sema_type = sema_type });
        const ref = inst.GlobalRef{ .id = id };
        try self.global_symtab.put(allocator, global_name, ref);
        return ref;
    }

    pub fn goToBlock(self: *Self, block: *BasicBlock) void {
        self.current_block = block;
    }
};
