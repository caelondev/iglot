const std = @import("std");
const ast = @import("../ast.zig");
const FaruParser = @import("../parser.zig").FaruParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const parseBlockStatement = @import("block_statement.zig").parseBlockStatement;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const tokens = @import("../../lexer/tokens.zig");
const Span = tokens.Span;

pub fn parseFunctionDeclarationStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;
    parser.nextToken();
    const fn_name: tokens.Token = parser.cur_tok;

    if (!try parser.expectPeek(allocator, .left_parenthesis)) return null;
    const fn_params = try parseFunctionParameters(parser, allocator) orelse return null;
    const fn_end_params_span = parser.cur_tok.span;

    var return_type: ast.TypeExpression = undefined;

    if (parser.peek_tok.kind == .left_brace) {
        try parser.reportError(allocator, .{
            .span = parser.cur_tok.span,
            .severity = .err,
            .kind = .MissingType,
        });
    } else {
        parser.nextToken();
        return_type = try pt.parseReturnTypeExpression(parser, allocator) orelse return null;
    }

    if (!try parser.expectPeek(allocator, .left_brace)) return null;
    const body = try parseBlockStatement(parser, allocator) orelse return null;

    return .{
        .span = Span.mergeFromSpans(keyword.span, body.span),
        .kind = .{
            .function_decl = .{
                .identifier = .{ .value = fn_name.lexeme },
                .return_type = return_type,
                .parameters = fn_params,
                .body = body,
                .span = Span.mergeFromSpans(keyword.span, fn_end_params_span),
            },
        },
    };
}

fn parseFunctionParameters(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?[]ast.FunctionParameter {
    var params: std.ArrayList(ast.FunctionParameter) = .empty;

    if (parser.peek_tok.kind == .right_parenthesis) {
        parser.nextToken();
        return try params.toOwnedSlice(allocator);
    }

    parser.nextToken();

    const first_ident = parser.cur_tok;
    if (!try parser.expectPeek(allocator, .box_colon)) return null;
    parser.nextToken();
    const first_ident_type = try pt.parseTypeExpression(parser, allocator) orelse return null;
    const first_param_span = Span.mergeFromSpans(first_ident.span, first_ident_type.span);

    try params.append(allocator, .{
        .span = first_param_span,
        .identifier = .{ .value = first_ident.lexeme },
        .param_type = first_ident_type,
    });

    while (parser.peek_tok.kind == .comma) {
        parser.nextToken();
        parser.nextToken();

        const ident = parser.cur_tok;
        if (!try parser.expectPeek(allocator, .box_colon)) return null;
        parser.nextToken();
        const ident_type = try pt.parseTypeExpression(parser, allocator) orelse return null;
        const param_span = Span.mergeFromSpans(ident.span, ident_type.span);

        try params.append(allocator, .{
            .span = param_span,
            .identifier = .{ .value = ident.lexeme },
            .param_type = ident_type,
        });
    }

    if (!try parser.expectPeek(allocator, .right_parenthesis)) return null;

    return try params.toOwnedSlice(allocator);
}
