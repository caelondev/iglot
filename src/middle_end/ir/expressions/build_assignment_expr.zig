const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const tokens = @import("../../../frontend/lexer/tokens.zig");
const tt = @import("../../../frontend/sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildAssignmentExpr(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, a: typed_ast.TypedAssignment) !inst.ValueRef {
    const rhs = try ir.buildExpr(allocator, a.value.*);
    const place = try ir.buildPlace(a.assignee.*);

    switch (place) {
        .local => |ref| {
            try ir.emit(allocator, .{
                .op = .store,
                .operands = try allocator.dupe(inst.ValueRef, &.{ ref, rhs }),
                .sema_type = sema_type,
                .data = .none,
                .result = null,
            });

            return ref;
        },
        .global => |ref| {
            try ir.emit(allocator, .{
                .op = .store_global,
                .operands = try allocator.dupe(inst.ValueRef, &.{rhs}),
                .sema_type = sema_type,
                .data = .{ .global = ref },
                .result = null,
            });

            return rhs;
        },
    }
}
