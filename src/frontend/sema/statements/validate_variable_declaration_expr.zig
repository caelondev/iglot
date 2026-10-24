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
            .annotations = if (i.is_builtin) &.{} else annotations,
        });

        return null;
    }

    var var_type: ?tt.SemaType = null;

    if (v.type) |t| {
        var_type = try tt.SemaType.fromTypeExpression(sema, allocator, t) orelse return null;
    }

    if (var_type) |ty| {
        if (ty == .void) {
            try sema.reportError(allocator, .{
                .span = v.type.?.span,
                .severity = .err,
                .kind = .{
                    .VoidValueStorage = .{
                        .identifier = v.identifier.value,
                    },
                },
            });

            return null;
        }
    }

    const value = try sema.validateExpression(
        allocator,
        v.value,
        v.value.span,
        var_type,
    ) orelse {
        // still declare so errors won't cascade
        try sema.type_table.declareIdentifier(
            allocator,
            v.identifier.value,
            .{
                .span = v.span,
                .sem_type = var_type orelse .err,
                .is_final = if (v.type) |t| t.kind == .final else false,
            },
        );

        return null;
    };

    if (var_type) |vtype| {
        if (!vtype.eql(value.sem_type)) {
            try sema.reportError(allocator, .{
                .span = v.value.span,
                .severity = .err,
                .kind = .{
                    .TypeMismatch = .{
                        .expected = vtype,
                        .found = value.sem_type,
                    },
                },
            });

            // preserve the declared type during error recovery
            try sema.type_table.declareIdentifier(
                allocator,
                v.identifier.value,
                .{
                    .span = v.span,
                    .sem_type = vtype,
                    .is_final = if (v.type) |t| t.kind == .final else false,
                },
            );

            return null;
        }
    }

    const resolved_type = var_type orelse value.sem_type;

    try sema.type_table.declareIdentifier(
        allocator,
        v.identifier.value,
        .{
            .span = v.span,
            .sem_type = resolved_type,
            .is_final = if (v.type) |t| t.kind == .final else false,
        },
    );

    return .{
        .identifier = v.identifier,
        .sema_type = resolved_type,
        .value = value,
    };
}
