const std = @import("std");
const ast = @import("../ast.zig");
const FaruParser = @import("../parser.zig").FaruParser;
const parseStatement = @import("parseStatement.zig").parseStatement;
const parseScopedStatement = @import("scoped_statement.zig").parseScopedStatement;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseLoopStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;
    parser.nextToken();

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
