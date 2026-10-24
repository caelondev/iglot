const std = @import("std");
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateArrayExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.ArrayExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const full_type = try tt.SemaType.fromTypeExpressionAllowInfer(sema, allocator, a.element_type) orelse return null;

    const arr = switch (full_type) {
        .array => |t| t,
        else => return null,
    };

    const elem_type = arr.element_type;

    if (elem_type.hasInfer()) {
        try sema.reportError(allocator, .{
            .span = span,
            .kind = .ArraySizeTypeInfer,
        });
        return null;
    }

    const size: tt.SemaArraySize = switch (arr.size) {
        .unknown => return null, // const-eval failed, already reported
        .infer => .{ .known = a.elements.len },
        .known => |n| blk: {
            if (n != a.elements.len) {
                try sema.reportError(allocator, .{
                    .span = span,
                    .kind = .{ .ArraySizeMismatch = .{
                        .expected = n,
                        .found = a.elements.len,
                    } },
                });
                return null;
            }
            break :blk .{ .known = n };
        },
    };

    var typed_elems: std.ArrayList(*typed_ast.TypedExpr) = .empty;

    for (a.elements) |expr| {
        const typed = try sema.validateExpression(allocator, expr, expr.span, elem_type.*) orelse return null;

        if (!elem_type.eql(typed.sem_type)) {
            try sema.reportError(allocator, .{
                .span = expr.span,
                .kind = .{ .TypeMismatch = .{
                    .expected = elem_type.*,
                    .found = typed.sem_type,
                } },
            });
            return null;
        }

        try typed_elems.append(allocator, typed);
    }

    const result_type: tt.SemaType = .{
        .array = .{
            .size = size,
            .element_type = elem_type,
        },
    };

    const node = try allocator.create(typed_ast.TypedExpr);
    node.* = .{
        .span = span,
        .sem_type = result_type,
        .kind = .{ .array = .{
            .elements = try typed_elems.toOwnedSlice(allocator),
            .sema_type = result_type,
        } },
    };

    return node;
}
