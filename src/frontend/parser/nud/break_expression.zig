const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseBreakExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Expression {
    _ = allocator;
    const keyword = parser.cur_tok;
    return .{
        .expr = .{
            .break_expr = .{
                .span = keyword.span,
            },
        },
        .span = keyword.span,
    };
}
