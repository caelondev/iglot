const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseContinueExpression(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Expression {
    _ = allocator;
    const keyword = parser.cur_tok;
    return .{
        .expr = .{
            .continue_expr = .{
                .span = keyword.span,
            },
        },
        .span = keyword.span,
    };
}
