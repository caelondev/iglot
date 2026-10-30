const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
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
    const typed_assignee = try sema.validateExpression(
        allocator,
        a.assignee,
        a.assignee.span,
        null,
    ) orelse return null;

    switch (typed_assignee.place) {
        .value => {
            try sema.reportError(allocator, .{
                .span = a.assignee.span,
                .kind = .InvalidLeftHandSideAssignment,
                .severity = .err,
            });
            return null;
        },
        .place => |p| try ensureAssignable(
            sema,
            allocator,
            a,
            p.mutability,
            p.root,
            p.projected,
        ) orelse return null,
    }

    const typed_value = try sema.validateExpression(
        allocator,
        a.value,
        a.value.span,
        typed_assignee.sem_type,
    ) orelse return null;

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
            .assignment = .{
                .assignee = typed_assignee,
                .value = typed_value,
            },
        },
    };

    return node;
}

fn writeAnnotation(allocator: std.mem.Allocator, span: Span, msg: []const u8) ![]IglotDiagnostic.Annotation {
    return try allocator.dupe(IglotDiagnostic.Annotation, &.{
        .{ .note = .{
            .message = msg,
            .span = span,
        } },
    });
}

/// checks that the place being assigned to is writable.
/// `projected` is true when the assignee is reached through an index (a[0]),
/// false when it's the variable itself (a).
fn ensureAssignable(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.AssignmentExpression,
    mutability: ast.TypeExpression.Mutability,
    root: ?typed_ast.Root,
    projected: bool,
) !?void {
    switch (mutability) {
        .final => {
            // final can be rebound, but not mutated through
            if (!projected) {
                const r = root.?;
                const annotations = try writeAnnotation(allocator, r.span, "identifier declared here");
                try sema.reportError(allocator, .{
                    .span = a.assignee.span,
                    .severity = .err,
                    .annotations = annotations,
                    .kind = .{ .FinalIdentifierAssignment = .{ .identifier = r.name } },
                });
                return null;
            }
        },

        .constant => {
            const r = root.?;
            const annotations = try writeAnnotation(allocator, r.span, "identifier declared here");
            try sema.reportError(allocator, .{
                .span = a.assignee.span,
                .severity = .err,
                .annotations = annotations,
                .kind = if (projected)
                    .{ .ConstIdentifierMutation = .{ .identifier = r.name } }
                else
                    .{ .ConstIdentifierAssignment = .{ .identifier = r.name } },
            });
            return null;
        },

        .function => {
            const r = root.?;
            const annotations = try writeAnnotation(allocator, r.span, "function declared here");
            try sema.reportError(allocator, .{
                .span = a.assignee.span,
                .severity = .err,
                .annotations = annotations,
                .kind = .{ .FunctionAssignment = .{ .identifier = r.name } },
            });
            return null;
        },

        .mutable => {},
    }
}
