const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildBinaryExpr(ir: *IglotIR, allocator: std.mem.Allocator, b: *const typed_ast.TypedBinaryExpr) !?inst.VReg {
    const op = tokenToOpcode(b.operator);
    const left_ref = try ir.buildExpression(allocator, b.left) orelse return null;
    const right_ref = try ir.buildExpression(allocator, b.right) orelse return null;
    const dest = ir.current_fn.newVReg();

    try ir.emit(allocator, .{
        .op = op,
        .sema_type = b.left.sem_type,
        .operands = try allocator.dupe(inst.VReg, &.{ left_ref, right_ref }),
        .result = dest,
        .data = .none,
    });

    return dest;
}

fn tokenToOpcode(kind: TokenKind) inst.Opcode {
    return switch (kind) {
        .plus => .add,
        .minus => .sub,
        .asterisk => .mul,
        .slash => .div,

        .less => .cmp_lt,
        .less_equal_to => .cmp_le,
        .greater => .cmp_gt,
        .greater_equal_to => .cmp_ge,
        .equal_to => .cmp_eq,
        .not_equal_to => .cmp_ne,

        .@"and" => .@"and",
        .@"or" => .@"or",
        else => unreachable,
    };
}
