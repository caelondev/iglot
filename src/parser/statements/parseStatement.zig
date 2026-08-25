const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("parseExpression.zig").parseExpression;

pub fn parseStatement(parser: *CiscoParser, allocator: std.mem.Allocator) !?ast.Statement {
    const expression = parseExpression(parser, allocator, .lowest) catch |e| {
        @panic(@errorName(e));
    };

    if (expression) |expr| {
        const stmt: ast.ExpressionStatement = .{
            .expression = expr,
            .span = expr.span,
        };
        return .{ .expression = stmt };
    }

    return null;
}
