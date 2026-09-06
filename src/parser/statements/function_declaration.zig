const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const parseBlockStatement = @import("block_statement.zig").parseBlockStatement;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseFunctionDeclarationStatement(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.advance();

    if (parser.cur_tok.kind == .identifier and parser.peek_tok.kind == .left_parenthesis) {
        try parser.reportError(allocator, .{
            .span = parser.cur_tok.span,
            .severity = .err,
            .kind = .MissingType,
        });
        return null;
    }

    const return_type =
        try pt.parseReturnTypeExpression(parser, allocator) orelse return null;
    const fn_name = try parser.expect(allocator, .identifier) orelse return null;
    const fn_params = try parseFunctionParameters(parser, allocator) orelse return null;
    const fn_params_span = parser.cur_tok.span;
    const body = try parseBlockStatement(parser, allocator) orelse return null;

    return .{
        .function_decl = .{
            .identifier = .{ .value = fn_name.lexeme },
            .return_type = return_type,
            .parameters = fn_params,
            .body = body,
            .span = Span.mergeFromSpans(keyword.span, fn_params_span),
        },
    };
}

fn parseFunctionParameters(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?[]ast.FunctionParameter {
    var params: std.ArrayList(ast.FunctionParameter) = .empty;

    _ = try parser.expect(allocator, .left_parenthesis) orelse return null;

    if (parser.cur_tok.kind == .right_parenthesis) {
        _ = parser.advance();
        return try params.toOwnedSlice(allocator);
    }

    const first_ident = try parser.expect(allocator, .identifier) orelse return null;
    _ = try parser.expect(allocator, .box_colon);
    const first_ident_type = try pt.parseTypeExpression(parser, allocator) orelse return null;
    const first_param_span = Span.mergeFromSpans(first_ident.span, first_ident_type.span);

    try params.append(allocator, .{
        .span = first_param_span,
        .identifier = .{ .value = first_ident.lexeme },
        .param_type = first_ident_type,
    });

    while (parser.cur_tok.kind == .comma) {
        _ = parser.advance();

        const ident = try parser.expect(allocator, .identifier) orelse return null;
        _ = try parser.expect(allocator, .box_colon);
        const ident_type = try pt.parseTypeExpression(parser, allocator) orelse return null;
        const param_span = Span.mergeFromSpans(ident.span, ident_type.span);

        try params.append(allocator, .{
            .span = param_span,
            .identifier = .{ .value = ident.lexeme },
            .param_type = ident_type,
        });
    }

    _ = try parser.expect(allocator, .right_parenthesis) orelse return null;

    return try params.toOwnedSlice(allocator);
}
