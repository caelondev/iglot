const std = @import("std");
const ast = @import("../ast.zig");
const FaruParser = @import("../parser.zig").FaruParser;
const parseStatement = @import("parseStatement.zig").parseStatement;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseBlockStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.BlockStatement {
    var stmts: std.ArrayList(ast.Statement) = .empty;

    const start = parser.cur_tok.span;
    parser.nextToken();

    while (!parser.curTokenIs(.right_brace) and !parser.curTokenIs(.eof)) {
        if (try parseStatement(parser, allocator)) |stmt| {
            try stmts.append(allocator, stmt);
        }
        parser.nextToken();
    }
    const end = parser.cur_tok.span;

    return .{ .span = Span.mergeFromSpans(start, end), .statements = try stmts.toOwnedSlice(allocator) };
}
