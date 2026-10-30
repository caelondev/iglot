const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildAssignmentExpr(ir: *IglotIR, allocator: std.mem.Allocator, a: *const typed_ast.TypedAssignment) !?inst.VReg {
    switch (a.assignee.kind) {
        .index => |i| {
            const dest = try ir.buildExpression(allocator, i.left) orelse return null;
            const index_ref = try ir.buildExpression(allocator, i.index) orelse return null;
            const rhs = try ir.buildExpression(allocator, a.value) orelse return null;

            try ir.emit(allocator, .{
                .op = .array_set,
                .sema_type = i.sema_type,
                .operands = try allocator.dupe(inst.VReg, &.{ dest, rhs }),
                .data = .{ .index = index_ref },
                .result = null,
            });

            return rhs;
        },
        .identifier => |*i| {
            const rhs = try ir.buildExpression(allocator, a.value) orelse return null;
            const ident = try ir.resolveIdentifier(allocator, i, a.assignee.sem_type);

            try ir.emit(allocator, .{
                .op = .mov,
                .sema_type = a.assignee.sem_type,
                .data = .none,
                .operands = try allocator.dupe(inst.VReg, &.{rhs}),
                .result = ident.reg,
            });

            return rhs;
        },

        else => unreachable,
    }
}
