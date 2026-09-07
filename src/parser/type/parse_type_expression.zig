const std = @import("std");

const FaruLexer = @import("../../lexer/faru_lexer.zig").FaruLexer;
const tokens = @import("../../lexer/tokens.zig");
const ast = @import("../ast.zig");
const FaruDiagnostic = @import("../../diagnostics/diagnostics.zig").FaruDiagnostic;

const nud_lit = @import("../nud/literals.zig");
const parseStatement = @import("../statements/parseStatement.zig").parseStatement;
const Precedence = @import("../precedence.zig").Precedence;
const FaruParser = @import("../parser.zig").FaruParser;

/// assumes cur_tok is already sitting on the type token when called
pub fn parseTypeExpression(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.TypeExpression {
    const tok = parser.cur_tok;

    switch (tok.kind) {
        .final => {
            parser.nextToken();
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

        else => return parseType(parser, allocator, tok),
    }
}

pub fn parseReturnTypeExpression(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.TypeExpression {
    return parseType(parser, allocator, parser.cur_tok);
}

fn parseType(
    parser: *FaruParser,
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
