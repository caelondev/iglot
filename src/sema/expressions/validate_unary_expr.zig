const std = @import("std");
const FaruDiagnostic = @import("../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateUnaryExpr(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    u: *const ast.UnaryExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const rhs = try sema.validateExpression(allocator, u.rhs, u.rhs.span, null) orelse return null;
    const result_type: tt.SemaType = switch (u.operator) {
        .bang => blk: {
            if (!rhs.sem_type.eql(.bool)) {
                try sema.reportError(allocator, .{
                    .span = u.rhs.span,
                    .kind = .{
                        .TypeMismatch = .{
                            .expected = .bool,
                            .found = rhs.sem_type,
                        },
                    },
                });
                return null;
            }
            break :blk .bool;
        },
        .minus => blk: {
            if (!rhs.sem_type.is_numerical()) {
                try sema.reportError(allocator, .{
                    .span = u.rhs.span,
                    .kind = .{
                        .TypeMismatch = .{
                            .expected = .number,
                            .found = rhs.sem_type,
                        },
                    },
                });
                return null;
            }
            break :blk rhs.sem_type;
        },
        else => unreachable,
    };

    const node = try allocator.create(typed_ast.TypedExpr);
    node.* = .{
        .span = span,
        .sem_type = result_type,
        .kind = .{
            .unary = .{
                .rhs = rhs,
                .operator = u.operator,
            },
        },
    };
    return node;
}
