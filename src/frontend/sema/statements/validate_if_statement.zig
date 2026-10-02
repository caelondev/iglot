const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateIfStatement(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    f: *const ast.IfStatement,
) anyerror!?typed_ast.TypedIfStatement {
    const cond = try sema.validateExpression(allocator, f.condition, f.condition.span, null) orelse return null;

    if (cond.sem_type != .bool) {
        try sema.reportError(allocator, .{
            .kind = .{ .TypeMismatch = .{ .expected = .bool, .found = cond.sem_type } },
            .span = cond.span,
        });
    }

    const conseq = try sema.validateStatement(allocator, f.consequence) orelse return null;

    const conseq_ptr = try allocator.create(typed_ast.TypedStmt);
    conseq_ptr.* = conseq;

    if (f.alternative == null) {
        return .{
            .condition = cond,
            .consequence = conseq_ptr,
            .alternative = null,
        };
    }

    const a = f.alternative orelse unreachable;
    const alt = try sema.validateStatement(allocator, a) orelse return null;

    const alt_ptr = try allocator.create(typed_ast.TypedStmt);
    alt_ptr.* = alt;

    return .{
        .condition = cond,
        .consequence = conseq_ptr,
        .alternative = alt_ptr,
    };
}
