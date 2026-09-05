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
const p = @import("../parser.zig");
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;
const statements = p.statements;
const CiscoParser = p.CiscoParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseStatement(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    if (getStatement(parser.cur_tok.kind)) |callback| {
        const s = try callback(parser, allocator) orelse {
            parser.synchronize();
            return null;
        };
        return s;
    }

    const expression = try parseExpression(
        parser,
        allocator,
        Precedence.lowest.toInt(),
    );

    const expr = expression orelse {
        parser.synchronize();
        return null;
    };

    _ = try parser.expect(allocator, .semicolon) orelse {
        parser.synchronize();
        return null;
    };

    const stmt: ast.ExpressionStatement = .{
        .expression = expr,
        .span = expr.span,
    };

    return .{ .expression = stmt };
}

fn getStatement(kind: TokenKind) ?p.StmtFn {
    for (statements) |stmt| {
        if (stmt.token_kind != kind) continue;
        return stmt.callback;
    }

    return null;
}
