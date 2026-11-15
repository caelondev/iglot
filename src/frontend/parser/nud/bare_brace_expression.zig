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
//! Parses bare brace expressions.
//!
//! A bare brace expression is a `{ ... }` literal with no type of its own.
//! The type comes from context (a typed declaration, a function argument,
//! a return type, an enclosing array literal) and is resolved in sema.
//! It has three shapes, picked by what follows the opening brace:
//!
//!     {}                              // empty, array or struct
//!     { 1, 2, 3, }                    // positional elements
//!     { .name = "bob", .age = 30, }   // named field
//!
//! The shape is chosen by the first token: a leading `.` means named
//! fields, anything else is positional. No lookahead needed.
//!
//! Every named field starts with its own `.`, and positional elements
//! can't start with one, so mixing the two shapes is a parse error in
//! either order:
//!
//!     { 1, .name = "x" }              // error, `.` can't start an expression
//!     { .name = "x", 1 }              // error, expected `.` before the field
//!
//! The first case relies on `.` having no prefix parse fn. If that ever
//! changes (enum shorthand like `.variant`, say), positional parsing will
//! start accepting it and mixing needs an explicit check.
//!
//! Both shapes parse their values above assignment precedence. A stray `=`
//! after a positional element (`{ x = 1 }`) is a syntax error instead of
//! being swallowed as an assignment expression, and a second `=` in a named
//! field (`{ .a = b = 1 }`) isn't read as chained assignment.
//!
//! A trailing comma is allowed in both shapes.
//!
//! `{}` stays unresolved in the AST because the parser cannot know whether
//! it is an empty array or an empty struct. Whether the shape matches the
//! expected type, and whether fields are missing, duplicated or unknown,
//! is left to sema.

const std = @import("std");

const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const Precedence = @import("../precedence.zig").Precedence;

const BareBrace = ast.BareBraceExpression;

/// assumes cur_tok is on '{'. leaves cur_tok on the closing '}'.
pub fn parseBareBraceExpression(parser: *IglotParser, allocator: std.mem.Allocator) anyerror!?ast.Expression {
    const l_brace = parser.cur_tok;

    if (parser.peekIs(.right_brace)) {
        parser.nextToken();
        return build(l_brace, .empty, parser);
    }

    parser.nextToken();

    // a leading '.' picks named fields, anything else is positional
    const body: BareBrace.Body = if (parser.curTokenIs(.dot))
        .{ .named = try parseNamedFields(parser, allocator) orelse return null }
    else
        .{ .positional = try parsePositionalElements(parser, allocator) orelse return null };

    if (!try parser.expectPeek(allocator, .right_brace)) return null;

    return build(l_brace, body, parser);
}

fn build(l_brace: anytype, body: BareBrace.Body, parser: *IglotParser) ast.Expression {
    return .{
        .span = .mergeFromSpans(l_brace.span, parser.cur_tok.span),
        .expr = .{ .bare_brace = .{ .body = body } },
    };
}

/// assumes cur_tok is on the first element. leaves cur_tok on the last
/// element or the trailing ',', so the caller can expectPeek('}').
fn parsePositionalElements(parser: *IglotParser, allocator: std.mem.Allocator) anyerror!?[]*ast.Expression {
    var elements: std.ArrayList(*ast.Expression) = .empty;

    while (true) {
        // above assignment so `x = 1` stops at '=' and errors at the caller
        const expr = try parseExpression(parser, allocator, Precedence.assignment.toInt()) orelse return null;

        const expr_ptr = try allocator.create(ast.Expression);
        expr_ptr.* = expr;
        try elements.append(allocator, expr_ptr);

        if (!parser.peekIs(.comma)) break;
        parser.nextToken(); // cur = ','
        if (parser.peekIs(.right_brace)) break; // trailing comma
        parser.nextToken(); // cur = next element
    }

    return try elements.toOwnedSlice(allocator);
}

/// assumes cur_tok is on the '.' of the first field. leaves cur_tok on the
/// last value or the trailing ',', so the caller can expectPeek('}').
fn parseNamedFields(parser: *IglotParser, allocator: std.mem.Allocator) anyerror!?[]BareBrace.FieldInit {
    var fields: std.ArrayList(BareBrace.FieldInit) = .empty;

    while (true) {
        // cur = '.', expectPeek reports the error if the name is missing
        if (!try parser.expectPeek(allocator, .identifier)) return null;
        const name = parser.cur_tok;

        if (!try parser.expectPeek(allocator, .assign)) return null;
        parser.nextToken();

        // above assignment so a second '=' isn't read as chained assignment
        const value = try parseExpression(parser, allocator, Precedence.assignment.toInt()) orelse return null;

        const value_ptr = try allocator.create(ast.Expression);
        value_ptr.* = value;
        try fields.append(allocator, .{ .name = name, .value = value_ptr });

        if (!parser.peekIs(.comma)) break;
        parser.nextToken(); // cur = ','
        if (parser.peekIs(.right_brace)) break; // trailing comma
        if (!try parser.expectPeek(allocator, .dot)) return null; // cur = '.'
    }

    return try fields.toOwnedSlice(allocator);
}
