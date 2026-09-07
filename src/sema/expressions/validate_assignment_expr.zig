const std = @import("std");
const FaruDiagnostic = @import("../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateAssignmentExpr(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.AssignmentExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    switch (a.assignee.expr) {
        .identifier => {
            const typed_assignee = try sema.validateExpression(allocator, a.assignee, a.assignee.span, null) orelse return null;
            const typed_value = try sema.validateExpression(allocator, a.value, a.value.span, null) orelse return null;

            const symbol = typed_assignee.kind.identifier;
            if (symbol.is_final) {
                try sema.reportError(allocator, .{
                    .span = a.assignee.span,
                    .severity = .err,
                    .kind = .{
                        .FinalIdentifierAssignment = .{ .identifier = symbol.value },
                    },
                });
                return null;
            }

            if (!typed_assignee.sem_type.eql(typed_value.sem_type)) {
                try sema.reportError(allocator, .{
                    .span = a.value.span,
                    .severity = .err,
                    .kind = .{
                        .TypeMismatch = .{
                            .expected = typed_assignee.sem_type,
                            .found = typed_value.sem_type,
                        },
                    },
                });

                return null;
            }

            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = span,
                .sem_type = typed_assignee.sem_type,
                .kind = .{
                    .assignment = .{ .assignee = typed_assignee, .value = typed_value },
                },
            };

            return node;
        },
        else => {
            try sema.reportError(
                allocator,
                .{
                    .span = a.assignee.span,
                    .kind = .InvalidLeftHandSideAssignment,
                    .severity = .err,
                },
            );
            return null;
        },
    }
}
