const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateBinaryExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    b: *const ast.BinaryExpression,
    span: Span,
    expected_type: ?tt.SemaType,
) anyerror!?*typed_ast.TypedExpr {
    const left = try sema.validateExpression(allocator, b.left, b.left.span, expected_type) orelse return null;
    const right = try sema.validateExpression(allocator, b.right, b.right.span, left.sem_type) orelse return null;

    if (!left.sem_type.eql(right.sem_type) and b.operator != .equal_to and b.operator != .not_equal_to) {
        try sema.reportError(allocator, .{
            .span = Span.mergeFromSpans(b.left.span, b.right.span),
            .kind = .{
                .InvalidBinaryExpressionType = .{ .left = left.sem_type, .right = right.sem_type, .operator = b.operator },
            },
        });
        return null;
    }

    return switch (b.operator) {
        .plus,
        .minus,
        .asterisk,
        .slash,
        => blk: {
            if (!left.sem_type.is_numerical()) {
                try sema.reportError(allocator, .{
                    .span = Span.mergeFromSpans(b.left.span, b.right.span),
                    .kind = .{
                        .TypeMismatch = .{ .expected = .number, .found = left.sem_type },
                    },
                });
                return null;
            }

            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = span,
                .sem_type = left.sem_type,
                .kind = .{ .binary = .{ .left = left, .right = right, .operator = b.operator } },
            };
            break :blk node;
        },

        .less,
        .greater,
        .less_equal_to,
        .greater_equal_to,
        => blk: {
            if (!left.sem_type.is_numerical()) {
                try sema.reportError(allocator, .{
                    .span = Span.mergeFromSpans(b.left.span, b.right.span),
                    .kind = .{
                        .TypeMismatch = .{ .expected = .number, .found = left.sem_type },
                    },
                });
                return null;
            }

            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = span,
                .sem_type = .bool,
                .kind = .{
                    .binary = .{
                        .left = left,
                        .right = right,
                        .operator = b.operator,
                    },
                },
            };
            break :blk node;
        },

        .equal_to, .not_equal_to => blk: {
            const l_null = left.sem_type == .null;
            const r_null = right.sem_type == .null;

            // comparing against null is only valid if the other side is nullable
            if (l_null or r_null) {
                const other = if (l_null) right else left;
                if (other.sem_type != .nullable) {
                    try sema.reportError(allocator, .{
                        .span = Span.mergeFromSpans(b.left.span, b.right.span),
                        .kind = .{
                            .InvalidBinaryExpressionType = .{ .left = left.sem_type, .right = right.sem_type, .operator = b.operator },
                        },
                    });
                    return null;
                }
            }

            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = span,
                .sem_type = .bool,
                .kind = .{ .binary = .{ .left = left, .right = right, .operator = b.operator } },
            };
            break :blk node;
        },

        .@"and", .@"or" => blk: {
            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = span,
                .sem_type = .bool,
                .kind = .{ .binary = .{ .left = left, .right = right, .operator = b.operator } },
            };
            break :blk node;
        },
        else => unreachable,
    };
}
