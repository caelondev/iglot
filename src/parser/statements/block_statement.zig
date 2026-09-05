const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseStatement = @import("parseStatement.zig").parseStatement;

pub fn parseBlockStatement(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.BlockStatement {
    _ = try parser.expect(allocator, .left_brace);

    var stmts: std.ArrayList(ast.Statement) = .empty;

    while (parser.cur_tok.kind != .right_brace) {
        const stmt = try parseStatement(parser, allocator) orelse return null;
        try stmts.append(allocator, stmt);
    }

    _ = try parser.expect(allocator, .right_brace);

    return .{ .statements = try stmts.toOwnedSlice(allocator) };
}
