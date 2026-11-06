const std = @import("std");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const ast = @import("../ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseMemberExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    const left_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;
    if (!try parser.expectPeek(allocator, .identifier)) return null;

    return .{
        .span = .mergeFromSpans(left.span, parser.cur_tok.span),
        .expr = .{
            .member = .{
                .object = left_ptr,
                .property = .{ .value = parser.cur_tok.lexeme, .span = parser.cur_tok.span },
            },
        },
    };
}
