const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const tokens = @import("../../../frontend/lexer/tokens.zig");
const tt = @import("../../../frontend/sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildUnaryExpr(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, u: typed_ast.TypedUnaryExpr) !inst.ValueRef {
    const rhs = try ir.buildExpr(allocator, u.rhs.*);
    const dest = ir.current_fn.newValue();

    const op: inst.Opcode = switch (u.operator) {
        .minus => .neg,
        .bang => .not,
        else => unreachable,
    };

    try ir.emit(allocator, .{
        .op = op,
        .operands = try allocator.dupe(inst.ValueRef, &.{rhs}),
        .result = dest,
        .data = .none,
        .sema_type = sema_type,
    });

    return rhs;
}
