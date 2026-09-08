const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../sema/typed_ast.zig");
const tokens = @import("../../lexer/tokens.zig");
const tt = @import("../../sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildUnaryExpr(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, u: typed_ast.TypedUnaryExpr) !inst.ValueRef {
    const rhs = try ir.buildExpr(allocator, u.rhs.*);

    const op: inst.Opcode = switch (u.operator) {
        .minus => .neg,
        .bang => .not,
        else => unreachable,
    };

    try ir.emit(allocator, .{
        .op = op,
        .operands = try allocator.dupe(inst.ValueRef, &.{rhs}),
        .result = null,
        .data = .none,
        .sema_type = sema_type,
    });

    return rhs;
}
