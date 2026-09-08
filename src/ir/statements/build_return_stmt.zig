const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../sema/typed_ast.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildReturn(ir: *FaruIR, allocator: std.mem.Allocator, r: typed_ast.TypedReturnStatement) !void {
    if (r.return_value == null) {
        try ir.emit(allocator, .{
            .op = .ret_void,
            .sema_type = null,
            .result = null,
            .operands = &.{},
            .data = .none,
        });
        return;
    }

    const val_expr = r.return_value orelse unreachable;
    const value = try ir.buildExpr(allocator, val_expr.*);

    try ir.emit(allocator, .{
        .op = .ret,
        .sema_type = r.return_value_type,
        .result = null,
        .operands = try allocator.dupe(inst.ValueRef, &.{value}),
        .data = .none,
    });
}
