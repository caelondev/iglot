const std = @import("std");
const ast = @import("../ast.zig");
const FaruParser = @import("../parser.zig").FaruParser;
const parseStatementRecovering = @import("parseStatement.zig").parseStatementRecovering;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseScopedStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.ScopedStatement {
    var stmts: std.ArrayList(ast.Statement) = .empty;

    const start = parser.cur_tok.span;
    parser.nextToken();

    while (!parser.curTokenIs(.right_brace) and !parser.curTokenIs(.eof)) {
        if (try parseStatementRecovering(parser, allocator)) |stmt| {
            try stmts.append(allocator, stmt);
        }
    }

    const end = parser.cur_tok.span;

    return .{ .span = Span.mergeFromSpans(start, end), .statements = try stmts.toOwnedSlice(allocator) };
}
