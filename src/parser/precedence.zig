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
//! The Cisco parser uses Pratt parsing to parse expressions according to
//! their operator precedence and associativity.
//!
//! Precedence determines how strongly an operator binds to its operands.
//! Higher precedence levels bind more tightly than lower levels, allowing
//! expressions such as `a + b * c` to be parsed as `a + (b * c)`.
//!
//! The precedence hierarchy ranges from `lowest`, which represents tokens
//! that do not participate in expression binding, through assignment,
//! conditional, logical, equality, comparison, additive, multiplicative,
//! exponentiation, call, index, and member access expressions.
//!
//! `Precedence.ofToken` maps a token to its corresponding precedence level.
//! Tokens that do not act as infix or postfix operators return `lowest`.
//!
//! The precedence values are ordered so that they can be compared directly
//! by the Pratt parser when determining whether the next token should be
//! consumed as part of the current expression.

const tokens = @import("../lexer/tokens.zig");

pub const Precedence = enum(u8) {
    lowest,
    assignment,
    declaration,
    conditional,
    logical_or,
    logical_and,
    equality,
    comparison,
    additive,
    multiplicative,
    exponent,
    unary,
    call,
    index,
    member,

    pub fn ofToken(token: tokens.Token) Precedence {
        return switch (token.kind) {
            .assign => .assignment,
            .box_colon => .declaration,

            .@"or" => .logical_or,
            .@"and" => .logical_and,

            .equal_to,
            .not_equal_to,
            => .equality,

            .less,
            .greater,
            .less_equal_to,
            .greater_equal_to,
            => .comparison,

            .plus,
            .minus,
            => .additive,

            .asterisk,
            .slash,
            => .multiplicative,

            .left_parenthesis => .call,
            .left_bracket => .index,
            .dot => .member,

            else => .lowest,
        };
    }

    pub fn toInt(self: Precedence) u8 {
        return @intFromEnum(self);
    }
};
