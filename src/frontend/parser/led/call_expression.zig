const std = @import("std");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const ast = @import("../ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseCallExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    const left_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;
    const args = try parseArgs(parser, allocator) orelse return null;

    return .{
        .span = .mergeFromSpans(left.span, parser.cur_tok.span),
        .expr = .{
            .call = .{
                .callee = left_ptr,
                .callee_kind = .defined,
                .arguments = args,
            },
        },
    };
}

pub fn parseCallBuiltinExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    if (!try parser.expectPeek(allocator, .left_parenthesis)) return null;

    const left_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;
    const args = try parseArgs(parser, allocator) orelse return null;

    return .{
        .span = .mergeFromSpans(left.span, parser.cur_tok.span),
        .expr = .{
            .call = .{
                .callee = left_ptr,
                .callee_kind = .builtin,
                .arguments = args,
            },
        },
    };
}

pub fn parseArgs(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?[]*ast.Expression {
    var args: std.ArrayList(*ast.Expression) = .empty;

    if (parser.peekIs(.right_parenthesis)) {
        parser.nextToken();
        return try args.toOwnedSlice(allocator);
    }

    parser.nextToken();
    const first = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;
    const first_ptr = try allocator.create(ast.Expression);
    first_ptr.* = first;

    try args.append(allocator, first_ptr);

    while (parser.peekIs(.comma)) {
        parser.nextToken();
        parser.nextToken();

        const arg = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;
        const arg_ptr = try allocator.create(ast.Expression);
        arg_ptr.* = arg;
        try args.append(allocator, arg_ptr);
    }

    if (!try parser.expectPeek(allocator, .right_parenthesis)) return null;
    return try args.toOwnedSlice(allocator);
}
