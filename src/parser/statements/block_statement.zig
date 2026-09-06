const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseStatement = @import("parseStatement.zig").parseStatement;

pub fn parseBlockStatement(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.BlockStatement {
    var stmts: std.ArrayList(ast.Statement) = .empty;

    parser.nextToken();

    while (!parser.curTokenIs(.right_brace) and !parser.curTokenIs(.eof)) {
        if (try parseStatement(parser, allocator)) |stmt| {
            try stmts.append(allocator, stmt);
        }
        parser.nextToken();
    }

    return .{ .statements = try stmts.toOwnedSlice(allocator) };
}
