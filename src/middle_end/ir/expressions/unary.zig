const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildUnaryExpr(ir: *FaruIR, allocator: std.mem.Allocator, u: *const typed_ast.TypedUnaryExpr) !?inst.VReg {
    const rhs_reg = try ir.buildExpression(allocator, u.rhs) orelse return null;
    const op: inst.Opcode = switch (u.operator) {
        .bang => .not,
        .minus => .neg,
        else => unreachable,
    };

    try ir.emit(allocator, .{
        .op = op,
        .sema_type = u.rhs.sem_type,
        .data = .none,
        .operands = try allocator.dupe(inst.VReg, &.{rhs_reg}),
        .result = null,
    });

    return rhs_reg;
}
