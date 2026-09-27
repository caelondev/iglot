const std = @import("std");
const ast = @import("../ast.zig");
const FaruParser = @import("../parser.zig").FaruParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const parseStatement = @import("parseStatement.zig").parseStatement;
const parseScopedStatement = @import("scoped_statement.zig").parseScopedStatement;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseIfStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;
    parser.nextToken();

    const cond = try parseExpression(
        parser,
        allocator,
        Precedence.lowest.toInt(),
    ) orelse {
        parser.skipMalformedBody();
        return null;
    };

    if (!try parser.expectPeek(allocator, .colon)) {
        parser.skipMalformedBody();
        return null;
    }

    var if_body: ast.Statement = undefined;

    if (parser.peekIs(.left_brace)) {
        parser.nextToken();

        const stmt = try parseScopedStatement(parser, allocator) orelse return null;

        if_body = .{
            .span = stmt.span,
            .kind = .{
                .scoped = stmt,
            },
        };
    } else {
        parser.nextToken();
        if_body = try parseStatement(parser, allocator) orelse return null;
    }

    const cond_ptr = try allocator.create(ast.Expression);
    cond_ptr.* = cond;

    const consequence_ptr = try allocator.create(ast.Statement);
    consequence_ptr.* = if_body;

    if (!parser.peekIs(.@"else")) {
        return .{
            .span = Span.mergeFromSpans(keyword.span, if_body.span),
            .kind = .{
                .if_stmt = .{
                    .condition = cond_ptr,
                    .consequence = consequence_ptr,
                    .alternative = null,
                },
            },
        };
    }

    parser.nextToken();

    var else_body: ast.Statement = undefined;

    if (parser.peekIs(.@"if")) {
        parser.nextToken();
        else_body = try parseIfStatement(parser, allocator) orelse return null;
    } else if (parser.peekIs(.left_brace)) {
        parser.nextToken();

        const stmt = try parseScopedStatement(parser, allocator) orelse return null;

        else_body = .{
            .span = stmt.span,
            .kind = .{
                .scoped = stmt,
            },
        };
    } else {
        parser.nextToken();
        else_body = try parseStatement(parser, allocator) orelse return null;
    }

    const alternative_ptr = try allocator.create(ast.Statement);
    alternative_ptr.* = else_body;

    return .{
        .span = Span.mergeFromSpans(keyword.span, else_body.span),
        .kind = .{
            .if_stmt = .{
                .condition = cond_ptr,
                .consequence = consequence_ptr,
                .alternative = alternative_ptr,
            },
        },
    };
}

