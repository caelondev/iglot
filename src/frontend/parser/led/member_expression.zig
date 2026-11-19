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
    errdefer allocator.destroy(left_ptr);

    if (parser.peekIs(.question)) {
        parser.nextToken();
        return .{
            .span = .mergeFromSpans(left.span, parser.cur_tok.span),
            .expr = .{
                .member = .{
                    .object = left_ptr,
                    .property = .null_unwrap,
                },
            },
        };
    }
    if (!try parser.expectPeek(allocator, .identifier)) return null;

    const prop_tok = parser.cur_tok;

    return .{
        .span = .mergeFromSpans(left.span, prop_tok.span),
        .expr = .{
            .member = .{
                .object = left_ptr,
                .property = .{
                    .ident = .{
                        .value = prop_tok.lexeme,
                        .span = prop_tok.span,
                    },
                },
            },
        },
    };
}
