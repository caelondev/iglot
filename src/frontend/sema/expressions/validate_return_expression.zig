const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

fn isAssignable(expected: tt.SemaType, found: tt.SemaType) bool {
    if (expected.eql(found)) return true;
    return switch (expected) {
        .nullable => |inner| found == .null or isAssignable(inner.*, found),
        else => false,
    };
}

pub fn validateReturnExpression(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    r: *const ast.ReturnExpression,
) anyerror!?typed_ast.TypedReturnExpression {
    const ctx = sema.current_function_ctx orelse {
        try sema.reportError(allocator, .{
            .span = r.span,
            .kind = .IllegalReturn,
        });
        return null;
    };

    const return_value: ?*typed_ast.TypedExpr = if (r.return_value) |val|
        try sema.validateExpression(allocator, val, val.span, ctx.return_type) orelse return null
    else
        null;

    const found_type: tt.SemaType = if (return_value) |rv|
        rv.sem_type
    else
        tt.SemaType.void;

    if (!isAssignable(ctx.return_type, found_type)) {
        try sema.reportError(allocator, .{
            .span = if (return_value) |rv| rv.span else r.span,
            .kind = .{
                .ReturnTypeMismatch = .{
                    .expected = ctx.return_type,
                    .found = found_type,
                },
            },
        });
        return null;
    }

    return .{
        .span = r.span,
        .return_value_type = found_type,
        .return_value = return_value,
    };
}
