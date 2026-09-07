const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../sema/typed_ast.zig");
const tokens = @import("../../lexer/tokens.zig");
const tt = @import("../../sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildBinaryExpr(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, b: typed_ast.TypedBinaryExpr) !inst.ValueRef {
    const left_ref = try ir.buildExpr(allocator, b.left.*);
    const right_ref = try ir.buildExpr(allocator, b.right.*);
    const dest = ir.current_fn.newValue();

    const op = operatorToOpcode(b.operator);

    try ir.emit(allocator, .{
        .op = op,
        .sema_type = sema_type,
        .result = dest,
        .operands = try allocator.dupe(inst.ValueRef, &.{ left_ref, right_ref }),
        .data = .none,
    });

    return dest;
}

fn operatorToOpcode(op: tokens.TokenKind) inst.Opcode {
    return switch (op) {
        .plus => .add,
        .minus => .sub,
        .asterisk => .mul,
        .slash => .div,

        .less => .cmp_lt,
        .greater => .cmp_gt,
        .less_equal_to => .cmp_le,
        .greater_equal_to => .cmp_ge,
        .equal_to => .cmp_eq,
        .not_equal_to => .cmp_ne,
        else => unreachable,
    };
}
