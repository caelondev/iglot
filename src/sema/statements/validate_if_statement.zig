const std = @import("std");
const FaruDiagnostic = @import("../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateIfStatement(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    f: *const ast.IfStatement,
) anyerror!?typed_ast.TypedIfStatement {
    const cond = try sema.validateExpression(allocator, f.condition, f.condition.span, null) orelse return null;
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
