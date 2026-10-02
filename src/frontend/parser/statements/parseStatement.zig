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
//! Parses statements in the Iglot language.
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
//!
//! `parseStatement` itself never recovers from an error — it reports one
//! (via `reportError`/`expectPeek`) and returns `null`. Error recovery is
//! owned entirely by `parseStatementRecovering`, which is the single call
//! site for `synchronize` in the whole statement-parsing pipeline. Every
//! loop that parses a sequence of statements (`parseProgram`,
//! `parseBlockStatement`, and any future block-like construct) must call
//! `parseStatementRecovering` instead of `parseStatement` directly. This
//! avoids the double-recovery bug where a leaf parser and its calling loop
//! both try to resynchronize the same failure, producing duplicate or
//! contradictory diagnostics.

const std = @import("std");
const ast = @import("../ast.zig");
const p = @import("../parser.zig");
const TokenKind = @import("../../lexer/tokens.zig").TokenKind;
const statements = p.statements;
const IglotParser = p.IglotParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseStatement(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    if (parser.curTokenIs(.identifier) and parser.peekTokenIs(.box_colon)) {
        return try @import("variable_declaration.zig").parseVariableDeclaration(parser, allocator);
    }

    if (getStatement(parser.cur_tok.kind)) |callback| {
        return try callback(parser, allocator);
    }

    const expr = try parseExpression(
        parser,
        allocator,
        Precedence.lowest.toInt(),
    ) orelse return null;

    if (!try parser.expectPeek(allocator, .semicolon)) {
        return null;
    }

    return .{
        .span = expr.span,
        .kind = .{
            .expression = .{
                .expression = expr,
                .span = expr.span,
            },
        },
    };
}

/// Parses one statement and owns recovery for it. This is the only
/// function in the parser that should ever call `synchronize`. Every
/// statement-sequence loop (`parseProgram`, `parseBlockStatement`, ...)
/// calls this instead of `parseStatement` directly.
///
/// On success, advances past the statement's last token (matching the
/// convention that a parse function leaves `cur_tok` on its last consumed
/// token). On failure, resynchronizes to the next safe boundary. If
/// `synchronize` makes no progress (e.g. it lands on a token the calling
/// loop has no way to consume, like a stray `}` at top level), forces a
/// single token of advancement so callers can never spin forever.
pub fn parseStatementRecovering(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const before = parser.advance_count;
    const stmt = try parseStatement(parser, allocator);

    if (parser.panic_mode) {
        parser.synchronize();

        if (!parser.madeProgress(before)) {
            parser.nextToken();
            parser.panic_mode = false;
        }
    } else if (stmt != null) {
        parser.nextToken();
    }

    return stmt;
}

fn getStatement(kind: TokenKind) ?p.StmtFn {
    for (statements) |stmt| {
        if (stmt.token_kind != kind) continue;
        return stmt.callback;
    }

    return null;
}
