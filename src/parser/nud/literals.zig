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
//! Parses literal and identifier expressions.
//!
//! These functions serve as null denotation (`nud`) handlers for the Pratt
//! expression parser. Each handler consumes its corresponding token and
//! constructs the appropriate AST expression.
//!
//! Integer literals are parsed as `i128` values. Values outside the
//! representable range are reported as `IntegerOverflow` parser errors.
//! Floating-point literals are parsed as `f64` values.
//!
//! Identifier and string literals retain their token lexemes as their AST
//! values.

const std = @import("std");

const CiscoParser = @import("../parser.zig").CiscoParser;
const ast = @import("../ast.zig");

pub fn parseInteger(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Expression {
    const lit_raw = parser.advance();

    const integer = std.fmt.parseInt(i128, lit_raw.lexeme, 10) catch |err| {
        switch (err) {
            error.Overflow => {
                try parser.reportError(
                    allocator,
                    .{
                        .span = lit_raw.span,
                        .kind = .ParseIntegerOverflow,
                    },
                );

                return null;
            },

            error.InvalidCharacter => unreachable,
        }
    };

    const integer_expr: ast.IntegerExpression = .{
        .value = integer,
    };

    return .{
        .expr = .{ .integer = integer_expr },
        .span = lit_raw.span,
    };
}

pub fn parseFloat(parser: *CiscoParser, _: std.mem.Allocator) !?ast.Expression {
    const lit_raw = parser.advance();

    const float = std.fmt.parseFloat(f64, lit_raw.lexeme) catch |err| {
        switch (err) {
            error.InvalidCharacter => unreachable,
        }
    };

    const float_expr: ast.FloatExpression = .{
        .value = float,
    };

    return .{
        .expr = .{ .float = float_expr },
        .span = lit_raw.span,
    };
}

pub fn parseIdentifier(parser: *CiscoParser, _: std.mem.Allocator) !?ast.Expression {
    const lit_raw = parser.advance();
    const ident_expr: ast.IdentifierExpression = .{ .value = lit_raw.lexeme };
    return .{
        .expr = .{ .identifier = ident_expr },
        .span = lit_raw.span,
    };
}

pub fn parseString(parser: *CiscoParser, _: std.mem.Allocator) !?ast.Expression {
    const lit_raw = parser.advance();
    const str_expr: ast.StringExpression = .{ .value = lit_raw.lexeme };
    return .{
        .expr = .{ .string = str_expr },
        .span = lit_raw.span,
    };
}
