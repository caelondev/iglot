//! Copyright (C) 2026  caelondev
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU Affero General Public License as published
//! by the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU Affero General Public License for more details.
//!
//! Parses binary expressions.
//!
//! `parseBinaryExpression` is a left denotation (`led`) handler used by the
//! Pratt expression parser. It consumes the binary operator following the
//! already-parsed left-hand expression, then parses the right-hand
//! expression using the operator's precedence.
//!
//! The resulting AST node contains the left and right expressions together
//! with the operator token. Its span covers the complete binary expression.
//!
//! If the right-hand side cannot be parsed, a
//! `MissingRightHandSideExpression` error is reported over the portion of
//! the expression that was successfully parsed and the current token.

const std = @import("std");

const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const ast = @import("../ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseBinaryExpression(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    const precedence = switch (parser.cur_tok.kind) {
        .assign => parser.curPrecedence() - 1,
        else => parser.curPrecedence(),
    };

    const op = parser.cur_tok;
    parser.nextToken();
    const full_span: Span = .mergeFromSpans(left.span, parser.cur_tok.span);
    const right = try parseExpression(parser, allocator, precedence) orelse return {
        try parser.reportError(allocator, .{
            .span = full_span,
            .kind = .MissingRightHandSideExpression,
        });

        return null;
    };

    const left_ptr = try allocator.create(ast.Expression);
    left_ptr.* = left;

    const right_ptr = try allocator.create(ast.Expression);
    right_ptr.* = right;

    const binary_expr: ast.BinaryExpression = .{
        .left = left_ptr,
        .operator = op.kind,
        .right = right_ptr,
    };

    return .{
        .expr = .{ .binary = binary_expr },
        .span = full_span,
    };
}
