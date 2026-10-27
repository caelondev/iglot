const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildArrayExpr(ir: *IglotIR, allocator: std.mem.Allocator, a: *const typed_ast.TypedArrayExpr) !?inst.VReg {
    const dest = ir.current_fn.newVReg();

    // evaluate every element first. codegen moves them into a consecutive
    // window, so the vregs here don't need to be adjacent.
    const elems = try allocator.alloc(inst.VReg, a.elements.len);
    for (a.elements, 0..) |elem, i| {
        elems[i] = try ir.buildExpression(allocator, elem) orelse return null;
    }

    try ir.emit(allocator, .{
        .op = .array_pack,
        .operands = elems,
        .result = dest,
        .sema_type = a.sema_type,
        .data = .{ .size = @intCast(elems.len) }, // sema already checked this
    });

    return dest;
}
