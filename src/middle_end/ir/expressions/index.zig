const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildIndexExpr(ir: *IglotIR, allocator: std.mem.Allocator, i: *const typed_ast.TypedIndexExpr) !?inst.VReg {
    const dest = ir.current_fn.newVReg();
    const idx_ref = try ir.buildExpression(allocator, i.index) orelse return null;
    const left_ref = try ir.buildExpression(allocator, i.left) orelse return null;

    // TODO: dispatch opcode depending on left's type
    try ir.emit(allocator, .{
        .op = .array_get,
        .result = dest,
        .data = .{ .index = idx_ref },
        .sema_type = i.sema_type,
        .operands = try allocator.dupe(inst.VReg, &.{left_ref}),
    });

    return dest;
}
