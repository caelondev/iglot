const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseFunctionDeclarationStatement(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    _ = parser;
    _ = allocator;
    return null;
}
