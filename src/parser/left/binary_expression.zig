const std = @import("std");

const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const ast = @import("../ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseBinaryExpression(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    const precedence = parser.cur_precedence();
    const op = parser.advance();
    const full_span: Span = .mergeFromSpans(left.span, parser.cur_tok.span);
    const right = try parseExpression(parser, allocator, precedence) orelse return {
        try parser.reportError(allocator, .{
            .span = full_span,
            .kind = .MissingRightHandSideExpression,
        });

        return null;
    };

    const left_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;

    const right_ptr = try allocator.create(ast.Expression);
    right_ptr.* = right;

    const binary_expr: ast.BinaryExpression = .{
        .left = left_ptr,
        .operator = op.kind,
        .right = right_ptr,
    };

    return .{
        .expr = .{ .binary = binary_expr },
        .span = full_span,
    };
}
