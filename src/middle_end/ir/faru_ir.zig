const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const typed_ast = @import("../../frontend/sema/typed_ast.zig");
const ast = @import("../../frontend/parser/ast.zig");
const tt = @import("../../frontend/sema/type_table.zig");

const buildFunctionDecl = @import("statements/function_decl.zig").buildFunctionDecl;
const buildReturnStmt = @import("statements/return.zig").buildReturnStmt;
const lit = @import("expressions/literal.zig");

pub const FaruIR = struct {
    type_table: tt.TypeTable,
    module: Module,
    current_fn: *Function,
    current_block: *BasicBlock,

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .type_table = undefined,
            .current_fn = undefined,
            .current_block = undefined,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.type_table.deinit(allocator);
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, t_ast: typed_ast.TypedProgram) !void {
        self.type_table = try .init(allocator);

        for (t_ast.body) |stmt| {
            try self.buildTopLevelStmt(allocator, stmt) orelse continue;
        }
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .function_decl => |*f| try buildFunctionDecl(self, allocator, f) orelse return null,
            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "illegal top level stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .return_stmt => |*r| try buildReturnStmt(self, allocator, r) orelse return null,

            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "TODO: build stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildExpression(self: *Self, allocator: std.mem.Allocator, expr: *const typed_ast.TypedExpr) !?inst.VReg {
        const sema_type = expr.sem_type;

        return switch (expr.kind) {
            .integer => |*i| try lit.buildIntegerLit(self, allocator, i, sema_type),
            .wide_integer => |*i| try lit.buildWideIntegerLit(self, allocator, i, sema_type),
            .float => |*f| try lit.buildFloatLit(self, allocator, f, sema_type),
            .string => |*s| try lit.buildStringLit(self, allocator, s, sema_type),
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

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.instructions.append(allocator, instruction);
    }

    pub fn goToBlock(self: *Self, block: *BasicBlock) void {
        self.current_block = block;
    }
};
