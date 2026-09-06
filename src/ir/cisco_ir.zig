const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const typed_ast = @import("../sema/typed_ast.zig");
const ast = @import("../parser/ast.zig");
const tt = @import("../sema/type_table.zig");

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
            .expression, .function_decl => @panic("TODO: not implemented yet"),
        }
    }

    pub fn buildExpr(self: *Self, allocator: std.mem.Allocator, expr: typed_ast.TypedExpr) !inst.ValueRef {
        return switch (expr.kind) {
            .integer => |i| try self.buildInteger(allocator, expr.sem_type, i),
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

        std.debug.print("RETURN VALUE = {}\n", .{value});

        try self.emit(allocator, .{
            .op = .ret,
            .sema_type = r.return_value_type,
            .result = null,
            .operands = try allocator.dupe(inst.ValueRef, &.{value}),
            .data = .none,
        });
    }

    pub fn buildInteger(self: *Self, allocator: std.mem.Allocator, sema_type: tt.SemaType, i: ast.IntegerExpression) !inst.ValueRef {
        const result = self.current_fn.newValue();

        const data: inst.Instruction.Data = switch (sema_type) {
            .wideint => .{ .wideint_literal = i.value },
            .int => .{ .int_literal = @intCast(i.value) },
            else => unreachable,
        };

        try self.emit(allocator, .{
            .op = if (sema_type == .wideint) .const_wideint else .const_int,
            .sema_type = sema_type,
            .result = result,
            .operands = &.{},
            .data = data,
        });

        return result;
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.append(allocator, instruction);
    }
};
