const std = @import("std");
const CiscoDiagnostic = @import("../../diagnostics/diagnostics.zig").CiscoDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const CiscoSemanticAnalyzer = @import("../sema.zig").CiscoSemanticAnalyzer;

pub fn validateVariableDeclaration(
    sema: *CiscoSemanticAnalyzer,
    allocator: std.mem.Allocator,
    v: *const ast.VariableDeclarationExpression,
) anyerror!?*typed_ast.TypedExpr {
    if (sema.type_table.lookupIdentifier(v.identifier.value)) |i| {
        const annotations = try allocator.dupe(CiscoDiagnostic.Annotation, &.{
            .{
                .note = .{
                    .message = "identifier declared here",
                    .span = i.span,
                },
            },
        });

        try sema.reportError(allocator, .{
            .span = v.span,
            .severity = .err,
            .kind = .{
                .IdentifierAlreadyExist = .{
                    .identifier = v.identifier.value,
                },
            },
            .annotations = annotations,
        });

        return null;
    }

    // TODO: add type inferrence instead of returning null
    const var_type = tt.SemaType.fromTypeExpression(v.type) orelse return null;
    try sema.type_table.declareIdentifier(allocator, v.identifier.value, .{ .span = v.span, .sem_type = var_type, .is_final = false });

    const value = try sema.validateExpression(allocator, v.value, v.value.span) orelse return null;
    if (!var_type.eql(value.sem_type)) {
        try sema.reportError(allocator, .{
            .span = v.value.span,
            .severity = .err,
            .kind = .{
                .TypeMismatch = .{ .expected = var_type, .found = value.sem_type },
            },
        });

        return null;
    }

    const node = try allocator.create(typed_ast.TypedExpr);
    node.* = .{
        .span = v.span,
        .sem_type = var_type,
        .kind = .{
            .variable_declaration = .{
                .identifier = v.identifier,
                .value = value,
            },
        },
    };
    return node;
}
