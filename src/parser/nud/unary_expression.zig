const std = @import("std");

const CiscoParser = @import("../parser.zig").CiscoParser;
const ast = @import("../ast.zig");
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const Precedence = @import("../precedence.zig").Precedence;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseUnaryExpression(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Expression {
    const operator = parser.cur_tok;
    parser.nextToken();

    const rhs = try parseExpression(
        parser,
        allocator,
        Precedence.unary.toInt(),
    ) orelse return null;

    const rhs_ptr = try allocator.create(ast.Expression);
    rhs_ptr.* = rhs;

    return .{
        .span = Span.mergeFromSpans(operator.span, rhs.span),
        .expr = .{
            .unary = .{
                .operator = operator.kind,
                .rhs = rhs_ptr,
            },
        },
    };
}
