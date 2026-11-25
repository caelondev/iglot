const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseReturnExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Expression {
    const keyword = parser.cur_tok;

    if (parser.peekTokenIs(.semicolon)) {
        return .{
            .span = keyword.span,
            .expr = .{
                .return_expr = .{
                    .return_value = null,
                    .span = keyword.span,
                },
            },
        };
    }

    parser.nextToken();

    const value = try allocator.create(ast.Expression);
    value.* = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;

    return .{
        .span = keyword.span,
        .expr = .{
            .return_expr = .{
                .return_value = value,
                .span = Span.mergeFromSpans(keyword.span, value.span),
            },
        },
    };
}
