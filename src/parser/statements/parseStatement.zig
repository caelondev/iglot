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
//! You should have received a copy of the GNU Affero General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.
//!
//! Parses statements in the Cisco language.
//!
//! Statement parsing acts as the entry point for parsing a single statement.
//! It determines which kind of statement can be parsed from the current
//! token and constructs the corresponding AST node.
//!
//! Expression statements are currently the only statement form supported.
//! An expression parsed at the lowest precedence is wrapped in an
//! `ast.ExpressionStatement` and returned as an `ast.Statement`.
//!
//! If no expression can be parsed at the current position, `parseStatement`
//! returns `null`, allowing the caller to determine whether the end of the
//! input or another statement boundary has been reached.

const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("parseExpression.zig").parseExpression;

pub fn parseStatement(parser: *CiscoParser, allocator: std.mem.Allocator) !?ast.Statement {
    const expression = parseExpression(parser, allocator, .lowest) catch |e| {
        @panic(@errorName(e));
    };

    if (expression) |expr| {
        const stmt: ast.ExpressionStatement = .{
            .expression = expr,
            .span = expr.span,
        };

        _ = parser.expect(allocator, .semicolon, expr.span) orelse return null;
        return .{ .expression = stmt };
    }

    return null;
}
