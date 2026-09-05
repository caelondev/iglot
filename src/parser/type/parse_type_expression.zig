const std = @import("std");

const CiscoLexer = @import("../../lexer/cisco_lexer.zig").CiscoLexer;
const tokens = @import("../../lexer/tokens.zig");
const ast = @import("../ast.zig");
const CiscoDiagnostic = @import("../../diagnostics/diagnostics.zig").CiscoDiagnostic;

const nud_lit = @import("../nud/literals.zig");
const parseStatement = @import("../statements/parseStatement.zig").parseStatement;
const Precedence = @import("../precedence.zig").Precedence;
const CiscoParser = @import("../parser.zig").CiscoParser;

pub fn parseTypeExpression(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.TypeExpression {
    const tok = parser.advance();

    switch (tok.kind) {
        .final => {
            const inner = try parseTypeExpression(parser, allocator) orelse return null;
            if (inner.kind == .final) {
                try parser.reportError(allocator, .{
                    .span = inner.span,
                    .severity = .err,
                    .kind = .RedundantFinal,
                });
                return null;
            }
            const inner_ptr = try allocator.create(ast.TypeExpression);
            inner_ptr.* = inner;
            return .{
                .span = tok.span,
                .kind = .{ .final = inner_ptr },
            };
        },

        else => {
            return parseType(parser, allocator, tok);
        },
    }
}

pub fn parseReturnTypeExpression(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.TypeExpression {
    const tok = parser.advance();
    return parseType(parser, allocator, tok);
}

fn parseType(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
    tok: tokens.Token,
) !?ast.TypeExpression {
    switch (tok.kind) {
        .identifier => {
            return .{
                .span = tok.span,
                .kind = .{ .identifier = tok.lexeme },
            };
        },

        else => |k| {
            try parser.reportError(allocator, .{
                .span = tok.span,
                .kind = .{ .UnexpectedTokenInType = .{ .found = k } },
            });
            return null;
        },
    }
}
