const std = @import("std");
const ast = @import("../ast.zig");
const literal = @import("../nud/literals.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;

pub fn parseExpression(parser: *CiscoParser, allocator: std.mem.Allocator) !?ast.Expression {
    return literal.parseInteger(parser, allocator);
}
