const std = @import("std");
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateIndexExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.IndexExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const left = try sema.validateExpression(allocator, a.left, a.left.span, null) orelse return null;

    const result_type = indexResultType(left.sem_type) orelse {
        try sema.reportError(allocator, .{
            .span = a.left.span,
            .kind = .{
                .InvalidIndexOperand = .{
                    .found_type = left.sem_type,
                },
            },
        });
        return null;
    };

    const index = try sema.validateExpression(allocator, a.index, a.index.span, null) orelse return null;
    if (requiresIntegerIndex(left.sem_type)) {
        if (!isIntegerType(index.sem_type)) {
            try sema.reportError(allocator, .{
                .span = index.span,
                .kind = .{
                    .InvalidIndexType = .{
                        .found = index.sem_type,
                        .left = .fixed_array,
                    },
                },
            });
        }
    }

    const node = try allocator.create(typed_ast.TypedExpr);
    node.* = .{
        .span = span,
        .sem_type = result_type,
        .kind = .{
            .index = .{
                .left = left,
                .index = index,
            },
        },
    };

    return node;
}

fn indexResultType(left_t: tt.SemaType) ?tt.SemaType {
    return switch (left_t) {
        .array => |arr| arr.element_type.*,

        // .string => .char, // TODO: implement string indexing
        .string,
        .constant,
        .any,
        .bool,
        .char,
        .double,
        .err,
        .float,
        .function,
        .int,
        .number,
        .void,
        .wideint,
        => null,
    };
}

fn requiresIntegerIndex(left_t: tt.SemaType) bool {
    return switch (left_t) {
        .array => true,

        .any,
        .bool,
        .char,
        .constant,
        .double,
        .err,
        .float,
        .function,
        .int,
        .number,
        .string,
        .void,
        .wideint,
        => false,
    };
}

fn isIntegerType(idx: tt.SemaType) bool {
    return switch (idx) {
        .wideint,
        .int,
        => true,

        .any,
        .array,
        .bool,
        .char,
        .constant,
        .double,
        .err,
        .float,
        .function,
        .number,
        .string,
        .void,
        => false,
    };
}
