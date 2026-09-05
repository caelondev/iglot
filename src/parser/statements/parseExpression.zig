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
//! Parses expressions using the Pratt parsing technique.
//!
//! Expression parsing is divided into two stages. The current token is
//! first handled by a null denotation (`nud`) function, which parses an
//! expression that begins with that token. This includes literals,
//! identifiers, prefix operators, and other prefix expressions.
//!
//! After the initial expression has been parsed, left denotation (`led`)
//! functions are used to extend it with infix and postfix expressions.
//! The parser continues consuming operators while their precedence is
//! higher than the precedence of the expression currently being parsed.
//!
//! `lookupNud` and `lookupLed` resolve token kinds to their corresponding
//! parser callbacks using the registered `nud_exprs` and `led_exprs` tables.
//! A token without a registered handler cannot begin or extend an expression.
//!
//! The precedence parameter limits how tightly the current expression may
//! bind. This allows recursive calls to `parseExpression` to correctly
//! construct the AST according to operator precedence and associativity.

const std = @import("std");
const ast = @import("../ast.zig");
const literal = @import("../nud/literals.zig");
const p = @import("../parser.zig");
const tokens = @import("../../lexer/tokens.zig");
const CiscoParser = p.CiscoParser;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseExpression(parser: *CiscoParser, allocator: std.mem.Allocator, precedence: u8) !?ast.Expression {
    const nud = lookupNud(parser.cur_tok.kind) orelse {
        try parser.reportError(allocator, .{
            .span = parser.cur_tok.span,
            .kind = .{ .UnexpectedToken = .{ .found = parser.cur_tok.kind } },
        });
        return null;
    };

    var left = try nud(parser, allocator) orelse return null;

    while (precedence < Precedence.ofToken(parser.cur_tok).toInt()) {
        const led = lookupLed(parser.cur_tok.kind) orelse break;
        left = try led(parser, allocator, left) orelse return null;
    }

    return left;
}

fn lookupNud(token_kind: tokens.TokenKind) ?p.NudFn {
    const nuds = p.nud_exprs;

    for (nuds) |n| {
        if (n.token_kind == token_kind) return n.callback;
    }

    return null;
}

fn lookupLed(token_kind: tokens.TokenKind) ?p.LedFn {
    const leds = p.led_exprs;

    for (leds) |l| {
        if (l.token_kind == token_kind) return l.callback;
    }

    return null;
}
