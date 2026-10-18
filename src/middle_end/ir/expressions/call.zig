const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const IglotIR = @import("../ir.zig").IglotIR;
const lookupBuiltin = @import("../../../vm/builtins.zig").lookupBuiltin;

pub fn buildCallExpr(ir: *IglotIR, allocator: std.mem.Allocator, c: *const typed_ast.TypedCallExpr) !?inst.VReg {
    var is_builtin = false;

    const callee_ref = blk: {
        if (c.callee.kind == .identifier) {
            const r = try ir.resolveIdentifier(allocator, &c.callee.kind.identifier, c.callee.sem_type);
            is_builtin = r.kind == .builtin;
            break :blk r.reg;
        }
        break :blk try ir.buildExpression(allocator, c.callee) orelse return null;
    };

    var args: std.ArrayList(inst.VReg) = .empty;
    for (c.arguments) |a| {
        const ref = try ir.buildExpression(allocator, a) orelse return null;
        try args.append(allocator, ref);
    }

    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .call = .{ .callee = callee_ref } },
        .op = if (is_builtin) .call_builtin else .call,
        .operands = try args.toOwnedSlice(allocator),
        .result = dest,
        .sema_type = c.sema_type,
    });
    return dest;
}
