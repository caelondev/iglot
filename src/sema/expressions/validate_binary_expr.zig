const std = @import("std");
const CiscoDiagnostic = @import("../../diagnostics/diagnostics.zig").CiscoDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const CiscoSemanticAnalyzer = @import("../sema.zig").CiscoSemanticAnalyzer;

pub fn validateBinaryExpr(sema: *CiscoSemanticAnalyzer, allocator: std.mem.Allocator, b: ast.BinaryExpression, span: Span) anyerror!?tt.SemaType {
    return switch (b.operator) {
        .plus, .minus, .asterisk, .slash, .assign => try validateArithmetic(sema, allocator, b, span),
        else => return .bool, // assume it's a comparison operators. hope this won't kill me later :3
    };
}

pub fn validateArithmetic(sema: *CiscoSemanticAnalyzer, allocator: std.mem.Allocator, b: ast.BinaryExpression, span: Span) anyerror!?tt.SemaType {
    _ = span;
    return switch (b.operator) {
        .plus,
        .minus,
        .asterisk,
        .slash,
        .assign,
        => {
            const l_type = try sema.validateExpression(allocator, @constCast(b.left).*, b.left.span) orelse return null;
            const r_type = try sema.validateExpression(allocator, @constCast(b.right).*, b.right.span) orelse return null;
            if (!l_type.eql(r_type)) {
                try sema.reportError(allocator, .{
                    .span = Span.mergeFromSpans(b.left.span, b.right.span),
                    .kind = .{
                        .InvalidBinaryExpressionType = .{ .left = l_type, .right = r_type, .operator = b.operator },
                    },
                });

                return null;
            }

            return l_type;
        },
        else => unreachable,
    };
}
