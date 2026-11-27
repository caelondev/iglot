//! Parses brace-delimited statement sequences.
//!
//! `parseBlockBody` is the shared implementation behind `parseBlockStatement`
//! (used by function declarations) and `parseScopedStatement` (used by every
//! other block-like construct). The two wrappers only differ in the AST type
//! they return.
//!
//! The parser expects `{` as the peek token. On entry `cur_tok` is the token
//! before the brace (for example the `:` or the closing `)` of a signature).
//! On success `cur_tok` is left on the closing `}`, matching the convention
//! that a parse function leaves `cur_tok` on its last consumed token.
//!
//! Each statement is parsed through `parseStatementRecovering`, so recovery
//! stays in one place and this file never calls `synchronize` itself.
//!
//! An unterminated block (EOF before `}`) reports an `ExpectedToken` error
//! for `.right_brace` and still returns the partial block, so later passes
//! see the statements that did parse.

const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseStatementRecovering = @import("parseStatement.zig").parseStatementRecovering;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseBlockBody(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?struct { span: Span, statements: []ast.Statement } {
    var stmts: std.ArrayList(ast.Statement) = .empty;

    const start = parser.cur_tok.span;
    if (!try parser.expectPeek(allocator, .left_brace)) return null;
    parser.nextToken();

    while (!parser.curTokenIs(.right_brace) and !parser.curTokenIs(.eof)) {
        if (try parseStatementRecovering(parser, allocator)) |stmt| {
            try stmts.append(allocator, stmt);
        }
    }

    if (!parser.curTokenIs(.right_brace)) {
        try parser.reportError(allocator, .{
            .span = parser.cur_tok.span,
            .kind = .{ .ExpectedToken = .{
                .expected = .right_brace,
                .found = parser.cur_tok.kind,
            } },
        });
    }

    return .{
        .span = Span.mergeFromSpans(start, parser.cur_tok.span),
        .statements = try stmts.toOwnedSlice(allocator),
    };
}

pub fn parseBlockStatement(parser: *IglotParser, allocator: std.mem.Allocator) !?ast.BlockStatement {
    const b = try parseBlockBody(parser, allocator) orelse return null;
    return .{ .span = b.span, .statements = b.statements };
}

pub fn parseScopedStatement(parser: *IglotParser, allocator: std.mem.Allocator) !?ast.ScopedStatement {
    const b = try parseBlockBody(parser, allocator) orelse return null;
    return .{ .span = b.span, .statements = b.statements };
}
