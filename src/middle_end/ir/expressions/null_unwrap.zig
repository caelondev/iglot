const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildNullUnwrapExpr(ir: *IglotIR, allocator: std.mem.Allocator, n: *const typed_ast.TypedNullUnwrap) !?inst.VReg {
    const src = try ir.buildExpression(allocator, n.left) orelse return null;
    const dest = ir.current_fn.newVReg();

    try ir.emit(allocator, .{
        .data = .none,
        .op = .unwrap_null,
        .operands = try allocator.dupe(inst.VReg, &.{src}),
        .result = dest,
        .sema_type = n.left.sem_type,
    });

    return dest;
}
