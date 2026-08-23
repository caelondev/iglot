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
//! Definitions for lexical tokens and their source locations.
//!
//! A `Token` represents a single lexical unit produced by the Cisco lexer.
//! Tokens contain their kind, the corresponding source lexeme, and the
//! source span where the token was found.
//!
//! Lexemes are slices of the original source buffer and do not own their
//! underlying memory. The source buffer must remain valid while tokens are
//! in use.
//!
//! `TokenKind` describes the syntactic category of a token, while `Span`
//! records its position within the source. Keywords are represented as
//! dedicated token kinds and are resolved through `keywords`.

const std = @import("std");

pub const TokenKind = enum {
    eof,
    illegal,
    @"error",

    string,
    number,
    identifier,

    plus,
    minus,
    asterisk,
    slash,
    assign,

    bang,
    @"and",
    @"or",

    less,
    greater,
    equal_to,
    not_equal_to,
    less_equal_to,
    greater_equal_to,

    left_brace,
    right_brace,
    left_parenthesis,
    right_parenthesis,
    left_bracket,
    right_bracket,

    semicolon,
    colon,
    dot,
    comma,
};

/// A source location covering a token.
pub const Span = struct {
    column_start: usize,
    column_end: usize,
    line_start: usize,
    line_end: usize,
};

/// A lexical token produced by the lexer.
pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    span: Span,

    /// Prints a human-readable representation of the token.
    pub fn debug(self: *Token) void {
        std.debug.print("{}-{}:{}-{} \"{s}\" ({s})\n", .{
            self.span.column_start,
            self.span.column_end,
            self.span.line_start,
            self.span.line_end,
            self.lexeme,
            @tagName(self.kind),
        });
    }
};

/// Maps keyword lexemes to their corresponding token kinds.
pub const keywords: std.StaticStringMap(TokenKind) = .initComptime(.{
    .{ "and", .@"and" },
    .{ "or", .@"or" },
});
