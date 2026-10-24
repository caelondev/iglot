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
//! Parses array literal expressions.
//!
//! An array literal begins with an array type (`[n]T` or `[_]T`), followed
//! by a brace-delimited, comma-separated list of expressions. A trailing
//! comma is allowed, and the list may be empty.
//!
//!     [3]int{ 1, 2, 3 };
//!     [_]int{ 1, 2, 3, };
//!     [_][2]int{
//!         [_]int{ 1, 2 },
//!         [_]int{ 3, 4 },
//!     };
//!
//! The parser only checks syntax. Whether `_` is legal in the size slot,
//! and whether the element count matches `n`, is left to sema.

const std = @import("std");

const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const parseTypeExpression = @import("../type/parse_type_expression.zig").parseTypeExpression;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseArrayExpression(parser: *IglotParser, allocator: std.mem.Allocator) !?ast.Expression {
    const l_bracket = parser.cur_tok;

    const arr_type = try parseTypeExpression(parser, allocator) orelse return null;

    if (!try parser.expectPeek(allocator, .left_brace)) return null;
    const elems = try parseElements(parser, allocator) orelse return null;
    if (!try parser.expectPeek(allocator, .right_brace)) return null;

    return .{
        .span = .mergeFromSpans(l_bracket.span, parser.cur_tok.span),
        .expr = .{
            .array = .{
                .element_type = arr_type,
                .elements = elems,
            },
        },
    };
}

/// assumes cur_tok is on '{'. leaves cur_tok on the last token of the
/// final element or on the trailing ',', so the caller can expectPeek('}').
pub fn parseElements(parser: *IglotParser, allocator: std.mem.Allocator) !?[]*ast.Expression {
    var elements: std.ArrayList(*ast.Expression) = .empty;

    while (!parser.peekIs(.right_brace)) {
        parser.nextToken();

        const expr = try parseExpression(parser, allocator, Precedence.lowest.toInt()) orelse return null;
        const expr_ptr = try allocator.create(ast.Expression);
        expr_ptr.* = expr;
        try elements.append(allocator, expr_ptr);

        // no comma means last element, caller's expectPeek('}') reports
        // the error if the next token isn't '}'
        if (!parser.peekIs(.comma)) break;
        parser.nextToken(); // onto ','
    }

    return try elements.toOwnedSlice(allocator);
}
