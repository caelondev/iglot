const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildExpressionStmt(ir: *FaruIR, allocator: std.mem.Allocator, e: *const typed_ast.TypedExpressionStmt) !?void {
    return switch (e.typed.kind) {
        .variable_declaration => |*v| try buildVarDecl(ir, allocator, v),
        .assignment => @panic("todo assignment expr stmt"),

        .binary,
        .call,
        .float,
        .identifier,
        .integer,
        .string,
        .unary,
        .wide_integer,
        => unreachable,
    };
}

pub fn buildVarDecl(self: *FaruIR, allocator: std.mem.Allocator, v: *const typed_ast.TypedVariableDeclaration) !?void {
    const value_reg = try self.buildExpression(allocator, v.value) orelse unreachable;
    try self.current_scope.declare(allocator, v.identifier.value, value_reg);
    return {};
}
