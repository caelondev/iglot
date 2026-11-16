const std = @import("std");
const ast = @import("../../../frontend/parser/ast.zig");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const builtins = @import("../../../vm/builtins.zig");
const IglotIR = @import("../ir.zig").IglotIR;
const SemaType = @import("../../../frontend/sema/type_table.zig").SemaType;
const lookupBuiltin = @import("../../../vm/builtins.zig").lookupBuiltin;

pub const IdentKind = enum {
    local,
    global,
    func,
    builtin,
};
pub const ResolvedIdent = struct {
    reg: inst.VReg,
    kind: IdentKind,
};

pub fn buildCallExpr(ir: *IglotIR, allocator: std.mem.Allocator, c: *const typed_ast.TypedCallExpr) !?inst.VReg {
    const callee_ref = blk: {
        if (c.callee.kind == .identifier) {
            const r = try resolveCallee(ir, allocator, &c.callee.kind.identifier, c.callee.sem_type, c.callee_kind);
            break :blk r.reg;
        }
        break :blk try ir.buildExpression(allocator, c.callee) orelse return null;
    };

    var args: std.ArrayList(inst.VReg) = .empty;
    for (c.arguments) |a| {
        const ref = try ir.buildExpression(allocator, a) orelse return null;
        try args.append(allocator, ref);
    }

    const op: inst.Opcode = switch (c.callee_kind) {
        .builtin => .call_builtin,
        .defined => .call,
    };

    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .call = .{ .callee = callee_ref } },
        .op = op,
        .operands = try args.toOwnedSlice(allocator),
        .result = dest,
        .sema_type = c.sema_type,
    });
    return dest;
}

fn resolveCallee(
    ir: *IglotIR,
    allocator: std.mem.Allocator,
    ident: *const typed_ast.TypedIdentifier,
    sem_type: SemaType,
    callee_kind: ast.CallExpression.CalleeKind,
) !ResolvedIdent {
    if (callee_kind == .defined) return try ir.resolveIdentifier(allocator, ident, sem_type);
    const i = builtins.lookupBuiltin(ident.value) orelse unreachable;
    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .builtin = i },
        .op = .load_builtin_fn,
        .operands = &.{},
        .sema_type = sem_type,
        .result = dest,
    });
    return .{ .reg = dest, .kind = .builtin };
}
