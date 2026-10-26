const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildArrayExpr(ir: *IglotIR, allocator: std.mem.Allocator, a: *const typed_ast.TypedArrayExpr) !?inst.VReg {
    const dest = ir.current_fn.newVReg();

    try ir.emit(allocator, .{
        .op = .array_new,
        .operands = &.{},
        .result = dest,
        .sema_type = a.sema_type,
        .data = .{ .index = @intCast(a.elements.len) }, // sema already checked this
    });

    for (a.elements, 0..) |elem, i| {
        const elem_ref = try ir.buildExpression(allocator, elem) orelse return null;
        try ir.emit(allocator, .{
            .op = .array_set,
            .result = null,
            .sema_type = elem.sem_type,
            .operands = try allocator.dupe(inst.VReg, &.{ dest, elem_ref }),
            .data = .{ .index = i },
        });
    }

    return dest;
}
