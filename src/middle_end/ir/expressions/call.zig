const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const IglotIR = @import("../ir.zig").IglotIR;
const lookupBuiltin = @import("../../../vm/builtins.zig").lookupBuiltin;

pub fn buildCallExpr(ir: *IglotIR, allocator: std.mem.Allocator, c: *const typed_ast.TypedCallExpr) !?inst.VReg {
    const dest = ir.current_fn.newVReg();
    var args: std.ArrayList(inst.VReg) = .empty;

    for (c.arguments) |a| {
        const ref = try ir.buildExpression(allocator, a) orelse return null;
        try args.append(allocator, ref);
    }

    if (c.callee.kind == .identifier) {
        const i = c.callee.kind.identifier;
        if (lookupBuiltin(i.value)) |id| {
            try ir.emit(allocator, .{
                .data = .{ .builtin = id },
                .op = .call_builtin,
                .operands = try args.toOwnedSlice(allocator),
                .result = dest,
                .sema_type = c.sema_type,
            });
            return dest;
        }
    }

    const callee_ref = try ir.buildExpression(allocator, c.callee) orelse return null;

    try ir.emit(allocator, .{
        .data = .{ .call = .{ .callee = callee_ref } },
        .op = .call,
        .operands = try args.toOwnedSlice(allocator),
        .result = dest,
        .sema_type = c.sema_type,
    });
    return dest;
}
