const std = @import("std");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const ast = @import("../ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseIndexExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    parser.nextToken();
    const idx = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;
    if (!try parser.expectPeek(allocator, .right_bracket)) return null;

    const left_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;

    const idx_ptr = try allocator.create(ast.Expression);
    idx_ptr.* = idx;

    return .{
        .span = .mergeFromSpans(left.span, parser.cur_tok.span),
        .expr = .{
            .index_expr = .{
                .left = left_ptr,
                .index = idx_ptr,
            },
        },
    };
}
