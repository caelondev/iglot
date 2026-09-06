const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const parseBlockStatement = @import("block_statement.zig").parseBlockStatement;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const Span = @import("../../lexer/tokens.zig").Span;

/// assumes cur_tok is sitting on the 'return' keyword when called
pub fn parseReturnStatement(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;

    parser.nextToken();

    if (parser.curTokenIs(.semicolon)) {
        return .{
            .return_stmt = .{
                .return_value = null,
                .span = keyword.span,
            },
        };
    }

    const value = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;

    if (!try parser.expectPeek(allocator, .semicolon)) return null;

    return .{
        .return_stmt = .{
            .return_value = value,
            .span = Span.mergeFromSpans(keyword.span, value.span),
        },
    };
}
