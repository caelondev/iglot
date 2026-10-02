const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateVariableDeclaration(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    v: *const ast.VariableDeclarationStatement,
) anyerror!?typed_ast.TypedVariableDeclaration {
    if (sema.type_table.lookupCurrentScope(v.identifier.value)) |i| {
        const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
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
    const var_type =
        try tt.SemaType.fromTypeExpression(allocator, v.type) orelse return null;

    if (var_type == .void) {
        try sema.reportError(allocator, .{
            .span = v.type.span,
            .severity = .err,
            .kind = .{
                .VoidValueStorage = .{ .identifier = v.identifier.value },
            },
        });

        return null;
    }

    try sema.type_table.declareIdentifier(
        allocator,
        v.identifier.value,
        .{
            .span = v.span,
            .sem_type = var_type,
            .is_final = v.type.kind == .final,
        },
    );

    const value = try sema.validateExpression(allocator, v.value, v.value.span, var_type) orelse return null;
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

    return .{
        .identifier = v.identifier,
        .sema_type = var_type,
        .value = value,
    };
}
