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
//! Parses statements in the Faru language.
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
const p = @import("../parser.zig");
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;
const statements = p.statements;
const FaruParser = p.FaruParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseStatement(
    parser: *FaruParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    if (getStatement(parser.cur_tok.kind)) |callback| {
        return try callback(parser, allocator) orelse {
            parser.synchronize();
            return null;
        };
    }

    const expr = try parseExpression(
        parser,
        allocator,
        Precedence.lowest.toInt(),
    ) orelse {
        parser.synchronize();
        return null;
    };

    if (!try parser.expectPeek(allocator, .semicolon)) {
        parser.synchronize();
        return null;
    }

    return .{
        .expression = .{
            .expression = expr,
            .span = expr.span,
        },
    };
}

fn getStatement(kind: TokenKind) ?p.StmtFn {
    for (statements) |stmt| {
        if (stmt.token_kind != kind) continue;
        return stmt.callback;
    }

    return null;
}
