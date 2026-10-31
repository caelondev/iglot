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
//! A `Token` represents a single lexical unit produced by the Iglot lexer.
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
    float,
    integer,
    wideint,
    identifier,

    plus,
    minus,
    asterisk,
    slash,
    assign,

    bang,

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
    dot_bracket,

    semicolon,
    colon,
    box_colon,
    dot,
    comma,

    // Keywords
    @"and",
    @"or",
    @"fn",
    @"return",
    @"if",
    @"else",
    @"break",
    @"const",
    @"struct",
    loop,
    final,
};

/// A source location covering a token.
pub const Span = struct {
    column_start: usize,
    column_end: usize,
    line_start: usize,
    line_end: usize,

    pub fn mergeFromSpans(span_start: Span, span_end: Span) Span {
        return .{
            .column_start = span_start.column_start,
            .column_end = span_end.column_end,
            .line_start = span_start.line_start,
            .line_end = span_end.line_end,
        };
    }

    pub fn empty() Span {
        return .{
            .column_start = 0,
            .column_end = 0,
            .line_start = 0,
            .line_end = 0,
        };
    }

    pub fn format(
        self: Span,
        writer: *std.Io.Writer,
    ) !void {
        try writer.print("{d}:{d}", .{
            self.line_start,
            self.column_start,
        });

        if (self.line_start == self.line_end) {
            if (self.column_start != self.column_end) {
                try writer.print("-{d}", .{
                    self.column_end,
                });
            }
        } else {
            try writer.print("-{d}:{d}", .{
                self.line_end,
                self.column_end,
            });
        }
    }
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
    .{ "fn", .@"fn" },
    .{ "return", .@"return" },
    .{ "if", .@"if" },
    .{ "else", .@"else" },
    .{ "break", .@"break" },
    .{ "const", .@"const" },
    .{ "struct", .@"struct" },
    .{ "fin", .final },
    .{ "loop", .loop },
});
