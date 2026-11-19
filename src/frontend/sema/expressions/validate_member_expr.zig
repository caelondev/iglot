const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateMemberExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    m: *const ast.MemberExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const obj = try sema.validateExpression(allocator, m.object, m.object.span, null) orelse return null;
    if (m.property == .null_unwrap) {
        if (obj.sem_type == .err) return null;
        if (obj.sem_type != .nullable) {
            const st = try allocator.create(tt.SemaType);
            st.* = obj.sem_type;
            try sema.reportError(allocator, .{
                .span = span,
                .kind = .{
                    .TypeMismatch = .{
                        .expected = .{ .nullable = st },
                        .found = obj.sem_type,
                    },
                },
            });

            return null;
        }

        const node = try allocator.create(typed_ast.TypedExpr);
        node.* = .{
            .kind = obj.kind,
            .span = obj.span,
            .place = obj.place,
            .sem_type = obj.sem_type.nullable.*,
        };
        return node;
    }

    const struct_type: *tt.SemaType.Struct = switch (obj.sem_type) {
        .@"struct" => |s| s,
        .err => return null,
        else => {
            try sema.reportError(allocator, .{
                .kind = .{
                    .NonStructAccess = .{
                        .sem_type = obj.sem_type,
                    },
                },
                .span = obj.span,
            });
            return null;
        },
    };

    const field_idx = struct_type.name_index_map.get(m.property.ident.value) orelse {
        try sema.reportError(allocator, .{
            .kind = .{ .UnknownField = .{ .name = m.property.ident.value, .struct_name = struct_type.name } },
            .span = obj.span,
        });
        return null;
    };

    const field = struct_type.fields[field_idx];
    const result = try allocator.create(typed_ast.TypedExpr);

    result.* = .{
        .kind = .{ .member = .{
            .object = obj,
            .property = .{
                .ident = .{
                    .value = field.name,
                    .mutability = field.mutability,
                },
            },
        } },
        .span = span,
        .sem_type = field.sema_type.*,
    };

    return result;
}
