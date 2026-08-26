const std = @import("std");

const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseGroupingExpression(parser: *CiscoParser, allocator: std.mem.Allocator) !?ast.Expression {
    _ = parser.advance();
    const expression = parseExpression(parser, allocator, .lowest);
    _ = parser.expect(.right_parenthesis) orelse return null;
    return expression;
}
