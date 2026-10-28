const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateAssignmentExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.AssignmentExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    switch (a.assignee.expr) {
        .identifier => |i| {
            const entry = sema.type_table.lookupIdentifier(i.value) orelse return null;

            if (entry.mutability == .final) {
                const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
                    .{ .note = .{
                        .message = "identifier declared here",
                        .span = entry.span,
                    } },
                });
                try sema.reportError(allocator, .{
                    .span = a.assignee.span,
                    .severity = .err,
                    .annotations = annotations,
                    .kind = .{ .FinalIdentifierAssignment = .{ .identifier = i.value } },
                });
                return null;
            }

            if (entry.mutability == .constant) {
                const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
                    .{ .note = .{
                        .message = "identifier declared here",
                        .span = entry.span,
                    } },
                });
                try sema.reportError(allocator, .{
                    .span = a.assignee.span,
                    .severity = .err,
                    .annotations = annotations,
                    .kind = .{ .ConstIdentifierAssignment = .{ .identifier = i.value } },
                });
                return null;
            }

            const typed_assignee = try sema.validateExpression(
                allocator,
                a.assignee,
                a.assignee.span,
                null,
            ) orelse return null;

            const typed_value = try sema.validateExpression(
                allocator,
                a.value,
                a.value.span,
                entry.sem_type, // expected type hint, drop if validateExpression doesn't want it here
            ) orelse return null;

            if (!entry.sem_type.eql(typed_value.sem_type)) {
                try sema.reportError(allocator, .{
                    .span = a.value.span,
                    .severity = .err,
                    .kind = .{
                        .TypeMismatch = .{
                            .expected = entry.sem_type,
                            .found = typed_value.sem_type,
                        },
                    },
                });
                return null;
            }

            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = span,
                .sem_type = entry.sem_type,
                .kind = .{
                    .assignment = .{
                        .assignee = typed_assignee,
                        .value = typed_value,
                    },
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
