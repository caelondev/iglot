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
//! Parses grouped expressions.
//!
//! A grouped expression begins with a left parenthesis, followed by an
//! expression, and ends with a right parenthesis. The inner expression is
//! parsed independently at the lowest precedence.
//!
//! Parentheses only affect the parsing of the enclosed expression and do
//! not produce a separate AST node. Once the closing parenthesis has been
//! consumed, the resulting expression is returned directly to the caller.

const std = @import("std");

const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseGroupingExpression(parser: *CiscoParser, allocator: std.mem.Allocator) !?ast.Expression {
    parser.nextToken();
    const expression = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;

    if (!try parser.expectPeek(allocator, .right_parenthesis)) return null;

    return expression;
}
