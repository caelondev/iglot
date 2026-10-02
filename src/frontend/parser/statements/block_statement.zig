const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseStatementRecovering = @import("parseStatement.zig").parseStatementRecovering;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseBlockStatement(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.BlockStatement {
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
