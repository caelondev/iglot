const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildCallExpr(ir: *IglotIR, allocator: std.mem.Allocator, c: *const typed_ast.TypedCallExpr) !?inst.VReg {
    const callee_ref = try ir.buildExpression(allocator, c.callee) orelse return null;
    const dest = ir.current_fn.newVReg();

    var args: std.ArrayList(inst.VReg) = .empty;

    for (c.arguments) |a| {
        const ref = try ir.buildExpression(allocator, a) orelse return null;
        try args.append(allocator, ref);
    }

    try ir.emit(allocator, .{
        .data = .{ .call = .{ .callee = callee_ref } },
        .op = .call,
        .operands = try args.toOwnedSlice(allocator),
        .result = dest,
        .sema_type = c.sema_type,
    });
    return dest;
}
