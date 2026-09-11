const std = @import("std");
const ast = @import("../ast.zig");
const FaruParser = @import("../parser.zig").FaruParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const parseBlockStatement = @import("block_statement.zig").parseBlockStatement;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseReturnStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;

    parser.nextToken();

    if (parser.curTokenIs(.semicolon)) {
        return .{
            .span = keyword.span,
            .kind = .{
                .return_stmt = .{
                    .return_value = null,
                    .span = keyword.span,
                },
            },
        };
    }

    const value = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;

    if (!try parser.expectPeek(allocator, .semicolon)) return null;

    return .{
        .span = keyword.span,
        .kind = .{
            .return_stmt = .{
                .return_value = value,
                .span = Span.mergeFromSpans(keyword.span, value.span),
            },
        },
    };
}
