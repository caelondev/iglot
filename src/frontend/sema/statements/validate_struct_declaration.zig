const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateStructDeclaration(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    s: *const ast.StructDeclarationStatement,
) anyerror!?typed_ast.TypedStructDeclarationStatement {
    if (sema.type_table.lookupCurrentScope(s.name.value)) |i| {
        const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
            .{
                .note = .{
                    .message = "identifier declared here",
                    .span = i.span,
                },
            },
        });

        try sema.reportError(allocator, .{
            .span = s.span,
            .severity = .err,
            .kind = .{
                .IdentifierAlreadyExist = .{
                    .identifier = s.name.value,
                },
            },
            .annotations = if (i.is_builtin) &.{} else annotations,
        });

        return null;
    }

    var name_index_map: std.StringHashMap(u32) = .init(allocator);
    var had_error = false;

    const typed_fields = try validateFields(sema, allocator, s.fields, &name_index_map, &had_error);

    // declared even when a field failed, so later uses of the struct don't
    // pile "undefined identifier" errors on top of the real one. bad fields
    // carry the `.err` poison type, which stops follow-up reports.
    try sema.type_table.declareType(allocator, s.name.value, .{
        .span = s.span,
        .mutability = .@"struct",
        .sem_type = .{
            .@"struct" = .{
                .name = s.name.value,
                .fields = typed_fields,
                .name_index_map = name_index_map,
            },
        },
    });

    if (had_error) return null;

    return .{
        .name = s.name,
        .fields = typed_fields,
    };
}

/// resolves every field and fills `name_index_map` (field name -> index).
/// keeps going after an error so all of them get reported in one pass.
/// duplicates are skipped so the indices stay dense and match `fields`.
fn validateFields(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    fields: []ast.StructDeclarationStatement.StructField,
    name_index_map: *std.StringHashMap(u32),
    had_error: *bool,
) ![]tt.SemaType.Struct.Field {
    var t_fields: std.ArrayList(tt.SemaType.Struct.Field) = .empty;

    for (fields, 0..) |f, ast_index| {
        const gop = try name_index_map.getOrPut(f.name.value);

        if (gop.found_existing) {
            const first = fields[findFirst(fields, f.name.value, ast_index)];
            const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
                .{ .note = .{
                    .message = "first declared here",
                    .span = first.name.span,
                } },
            });

            try sema.reportError(allocator, .{
                .span = f.name.span,
                .kind = .{ .DuplicateField = .{ .name = f.name.value } },
                .annotations = annotations,
            });

            had_error.* = true;
            continue;
        }

        gop.value_ptr.* = @intCast(t_fields.items.len);

        var s_type = try tt.SemaType.fromTypeExpression(sema, allocator, f.type_expr) orelse blk: {
            had_error.* = true;
            break :blk .err;
        };

        if (try s_type.rejectVoid(sema, allocator, f.type_expr.span, "a struct field type")) {
            had_error.* = true;
            s_type = .err;
        }

        const s_type_ptr = try allocator.create(tt.SemaType);
        s_type_ptr.* = s_type;
        try t_fields.append(allocator, .{
            .name = f.name.value,
            .sema_type = s_type_ptr,
            .span = f.name.span,
        });
    }

    return try t_fields.toOwnedSlice(allocator);
}

/// index of the first ast field named `name`, searching before `limit`.
fn findFirst(
    fields: []ast.StructDeclarationStatement.StructField,
    name: []const u8,
    limit: usize,
) usize {
    for (fields[0..limit], 0..) |f, i| {
        if (std.mem.eql(u8, f.name.value, name)) return i;
    }
    return limit;
}
