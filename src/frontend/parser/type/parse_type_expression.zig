const std = @import("std");

const IglotLexer = @import("../../lexer/lexer.zig").IglotLexer;
const tokens = @import("../../lexer/tokens.zig");
const ast = @import("../ast.zig");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;

const nud_lit = @import("../nud/literals.zig");
const parseStatement = @import("../statements/parseStatement.zig").parseStatement;
const Precedence = @import("../precedence.zig").Precedence;
const IglotParser = @import("../parser.zig").IglotParser;

/// assumes cur_tok is already sitting on the type token when called
pub fn parseTypeExpression(
    parser: *IglotParser,
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
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.TypeExpression {
    return parseType(parser, allocator, parser.cur_tok);
}

fn parseType(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
    tok: tokens.Token,
) anyerror!?ast.TypeExpression {
    switch (tok.kind) {
        .identifier => {
            return .{
                .span = tok.span,
                .kind = .{ .identifier = tok.lexeme },
            };
        },

        .@"fn" => {
            if (!try parser.expectPeek(allocator, .left_parenthesis)) return null;

            var params: std.ArrayList(*ast.TypeExpression) = .empty;

            if (!parser.peekIs(.right_parenthesis)) {
                parser.nextToken();

                const first = try parseTypeExpression(parser, allocator) orelse return null;
                const first_ptr = try allocator.create(ast.TypeExpression);
                first_ptr.* = first;
                try params.append(allocator, first_ptr);

                while (parser.peekIs(.comma)) {
                    parser.nextToken();
                    parser.nextToken();

                    const param = try parseTypeExpression(parser, allocator) orelse return null;
                    const param_ptr = try allocator.create(ast.TypeExpression);
                    param_ptr.* = param;
                    try params.append(allocator, param_ptr);
                }
            }

            if (!try parser.expectPeek(allocator, .right_parenthesis)) return null;

            parser.nextToken();

            const ret = try parseTypeExpression(parser, allocator) orelse return null;
            const ret_ptr = try allocator.create(ast.TypeExpression);
            ret_ptr.* = ret;

            return .{
                .span = tokens.Span.mergeFromSpans(tok.span, ret.span),
                .kind = .{
                    .function = .{
                        .parameters = try params.toOwnedSlice(allocator),
                        .return_type = ret_ptr,
                    },
                },
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
