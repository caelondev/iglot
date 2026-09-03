const std = @import("std");

const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const ast = @import("../ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseAssignmentExpression(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    _ = parser.advance();
    const rhs = try parseExpression(parser, allocator, Precedence.assignment.toInt() - 1) orelse return null;
    const left_ptr = try allocator.create(ast.Expression);
    const rhs_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;
    rhs_ptr.* = rhs;

    return .{
        .span = Span.mergeFromSpans(left.span, rhs.span),
        .expr = .{
            .assignment = .{
                .assignee = left_ptr,
                .value = rhs_ptr,
            },
        },
    };
}
