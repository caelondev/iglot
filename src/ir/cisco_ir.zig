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

pub const CiscoIR = struct {
    module: Module,
    current_fn: *Function = undefined,
    current_block: *BasicBlock = undefined,
    locals: std.StringHashMap(inst.ValueRef),

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .locals = undefined,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.module.deinit(allocator);
        self.locals.deinit();
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, program: typed_ast.TypedProgram) !void {
        self.locals = .init(allocator);

        for (program.body) |stmt| {
            try self.buildTopLevelStmt(allocator, stmt);
        }
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !void {
        switch (stmt) {
            .function_decl => |f| try self.buildFunction(allocator, f),
            else => unreachable,
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !void {
        switch (stmt) {
            .return_stmt => |r| try self.buildReturn(allocator, r),
            .expression => |e| _ = try self.buildExpr(allocator, e.typed.*),
            .function_decl => @panic("TODO: not implemented yet"),
        }
    }

    pub fn buildExpr(self: *Self, allocator: std.mem.Allocator, expr: typed_ast.TypedExpr) anyerror!inst.ValueRef {
        return switch (expr.kind) {
            .integer => |i| try b_lit.buildInteger(self, allocator, expr.sem_type, i),
            .binary => |b| try buildBinaryExpr(self, allocator, expr.sem_type, b),
            .variable_declaration => |v| try buildVariableDecl(self, allocator, expr.sem_type, v),
            else => @panic("TODO: expr kind not implemented yet"),
        };
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

        for (decl.body.typed_stmts) |stmt| {
            try self.buildStmt(allocator, stmt);
        }

        if (!self.current_block.isTerminated()) {
            // sema guarantees that this function is void
            try self.emit(allocator, .{
                .op = .ret_void,
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

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.append(allocator, instruction);
    }
};
