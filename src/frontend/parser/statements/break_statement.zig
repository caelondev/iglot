const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseBreakStatement(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const keyword = parser.cur_tok;
    if (!try parser.expectPeek(allocator, .semicolon)) return null;

    return .{
        .kind = .{
            .break_stmt = .{
                .span = keyword.span,
            },
        },
        .span = keyword.span,
    };
}
