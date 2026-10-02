const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseStatement = @import("parseStatement.zig").parseStatement;
const parseScopedStatement = @import("scoped_statement.zig").parseScopedStatement;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseLoopStatement(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;

    if (!try parser.expectPeek(allocator, .left_brace)) return null;

    const body = try parseScopedStatement(parser, allocator) orelse return null;
    return .{
        .span = Span.mergeFromSpans(keyword.span, body.span),
        .kind = .{
            .loop = .{
                .body = body,
            },
        },
    };
}
