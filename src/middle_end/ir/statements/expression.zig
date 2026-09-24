const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildExpressionStmt(ir: *FaruIR, allocator: std.mem.Allocator, e: *const typed_ast.TypedExpressionStmt) !?void {
    _ = ir;
    _ = allocator;
    return switch (e.typed.kind) {
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
