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
        .member => |*m| {
            const obj = try ir.buildExpression(allocator, m.object) orelse return null;
            const rhs = try ir.buildExpression(allocator, a.value) orelse return null;

            // object's sem_type is guaranteed to be a struct by sema
            const struct_type = m.object.sem_type.@"struct";
            const field_idx: u32 = @intCast(struct_type.name_index_map.get(m.property.value).?);

            try ir.emit(allocator, .{
                .op = .struct_set,
                .sema_type = a.assignee.sem_type,
                .operands = try allocator.dupe(inst.VReg, &.{ obj, rhs }),
                .data = .{ .field_index = field_idx },
                .result = null,
            });

            return rhs;
        },

        else => unreachable,
    }
}
