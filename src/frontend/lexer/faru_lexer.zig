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
//! The Faru lexer converts a null-terminated source buffer into a stream
//! of lexical tokens.
//!
//! The lexer recognizes identifiers, keywords, numeric and string literals,
//! punctuation, operators, and illegal characters. Whitespace is consumed
//! internally and does not produce tokens.
//!
//! Tokens retain slices of the original source buffer rather than allocating
//! new memory. The caller must therefore keep `source` alive and unchanged
//! for as long as the produced tokens are used.
//!
//! Each token also carries source-location information describing its
//! beginning and ending line and column.
//!
//! `FaruLexer.nextToken` advances the lexer by one token on each call and
//! eventually returns an `.eof` token once the source has been exhausted.
//! Lexical errors are represented as `.error` tokens.

const std = @import("std");
const tokens = @import("tokens.zig");

pub const FaruLexer = struct {
    source: []u8,
    cursor: usize,

    prev_line: usize,
    cur_line: usize,

    prev_col: usize,
    cur_col: usize,

    const State = enum {
        start,
        identifier,
        numeric,
        strings,
    };

    const Self = @This();
    pub fn init(source: []u8) Self {
        return .{
            .source = source,
            .cursor = 0,

            .prev_col = 1,
            .cur_col = 1,

            .prev_line = 1,
            .cur_line = 1,
        };
    }

    pub fn nextToken(self: *Self) tokens.Token {
        var start = self.cursor;

        lexer: switch (State.start) {
            .start => {
                if (self.isAtEnd()) {
                    return .{
                        .kind = .eof,
                        .lexeme = "END_OF_FILE",
                        .span = .{
                            .column_start = self.cur_col,
                            .column_end = self.cur_col,
                            .line_start = self.cur_line,
                            .line_end = self.cur_line,
                        },
                    };
                }

                start = self.cursor;
                self.prev_col = self.cur_col;
                self.prev_line = self.cur_line;

                const c = self.cur();
                switch (c) {
                    // skip whitespaces
                    ' ', '\t', '\n', '\r' => {
                        while (!self.isAtEnd()) {
                            switch (self.cur()) {
                                ' ', '\t', '\n', '\r' => {
                                    if (self.cur() == '\n') {
                                        self.advance();
                                        self.cur_col = 1;
                                        self.cur_line += 1;
                                    } else {
                                        self.advance();
                                    }
                                },
                                else => break,
                            }
                        }

                        continue :lexer .start;
                    },

                    // idents
                    'a'...'z', 'A'...'Z', '_' => {
                        self.advance();
                        continue :lexer .identifier;
                    },

                    '0'...'9' => {
                        self.advance();
                        continue :lexer .numeric;
                    },

                    '"' => {
                        self.advance();
                        start = self.cursor;
                        continue :lexer .strings;
                    },

                    '[' => {
                        self.advance();
                        return self.newToken(.left_bracket, self.source[start..self.cursor]);
                    },
                    ']' => {
                        self.advance();
                        return self.newToken(.right_bracket, self.source[start..self.cursor]);
                    },
                    '{' => {
                        self.advance();
                        return self.newToken(.left_brace, self.source[start..self.cursor]);
                    },
                    '}' => {
                        self.advance();
                        return self.newToken(.right_brace, self.source[start..self.cursor]);
                    },
                    '(' => {
                        self.advance();
                        return self.newToken(.left_parenthesis, self.source[start..self.cursor]);
                    },
                    ')' => {
                        self.advance();
                        return self.newToken(.right_parenthesis, self.source[start..self.cursor]);
                    },

                    '+' => {
                        self.advance();
                        return self.newToken(.plus, self.source[start..self.cursor]);
                    },
                    '-' => {
                        self.advance();
                        return self.newToken(.minus, self.source[start..self.cursor]);
                    },
                    '*' => {
                        self.advance();
                        return self.newToken(.asterisk, self.source[start..self.cursor]);
                    },
                    '/' => {
                        self.advance();
                        return self.newToken(.slash, self.source[start..self.cursor]);
                    },

                    '>' => {
                        start = self.cursor;
                        self.advance();

                        if (self.cur() == '=') {
                            self.advance();
                            return self.newToken(.greater_equal_to, self.source[start..self.cursor]);
                        }

                        return self.newToken(.greater, self.source[start..self.cursor]);
                    },
                    '<' => {
                        start = self.cursor;
                        self.advance();

                        if (self.cur() == '=') {
                            self.advance();
                            return self.newToken(.less_equal_to, self.source[start..self.cursor]);
                        }

                        return self.newToken(.less, self.source[start..self.cursor]);
                    },
                    '=' => {
                        start = self.cursor;
                        self.advance();

                        if (self.cur() == '=') {
                            self.advance();
                            return self.newToken(.equal_to, self.source[start..self.cursor]);
                        }

                        return self.newToken(.assign, self.source[start..self.cursor]);
                    },
                    '!' => {
                        start = self.cursor;
                        self.advance();

                        if (self.cur() == '=') {
                            self.advance();
                            return self.newToken(.not_equal_to, self.source[start..self.cursor]);
                        }

                        return self.newToken(.bang, self.source[start..self.cursor]);
                    },

                    ';' => {
                        self.advance();
                        return self.newToken(.semicolon, self.source[start..self.cursor]);
                    },
                    ':' => {
                        start = self.cursor;
                        self.advance();

                        if (self.cur() == ':') {
                            self.advance();
                            return self.newToken(.box_colon, self.source[start..self.cursor]);
                        }

                        return self.newToken(.colon, self.source[start..self.cursor]);
                    },
                    ',' => {
                        self.advance();
                        return self.newToken(.comma, self.source[start..self.cursor]);
                    },
                    '.' => {
                        self.advance();
                        return self.newToken(.dot, self.source[start..self.cursor]);
                    },

                    else => {
                        self.advance();
                        return self.newToken(.illegal, self.source[start..self.cursor]);
                    },
                }
            },

            .identifier => {
                while (!self.isAtEnd()) {
                    switch (self.cur()) {
                        'a'...'z', 'A'...'Z', '_', '0'...'9' => {
                            self.advance();
                        },

                        else => break,
                    }
                }

                const lexeme = self.source[start..self.cursor];
                if (tokens.keywords.get(lexeme)) |kind| {
                    return self.newToken(kind, lexeme);
                } else return self.newToken(.identifier, lexeme);
            },

            .numeric => {
                while (!self.isAtEnd()) {
                    switch (self.cur()) {
                        '0'...'9', '.' => {
                            self.advance();
                            if (self.cur() == '.') {
                                self.advance();

                                while (!self.isAtEnd()) {
                                    switch (self.cur()) {
                                        '0'...'9' => self.advance(),
                                        else => break,
                                    }
                                }

                                break;
                            }
                        },

                        else => break,
                    }
                }

                const lexeme = self.source[start..self.cursor];
                if (std.mem.indexOfScalar(u8, lexeme, '.')) |_| {
                    return self.newToken(.float, lexeme);
                }

                if (self.cur() == 'w') {
                    self.advance();
                    return self.newToken(.wideint, lexeme);
                }

                return self.newToken(.integer, lexeme);
            },

            .strings => {
                while (!self.isAtEnd() and self.cur() != '"') {
                    self.advance();
                }

                if (self.isAtEnd()) {
                    return self.errorToken("unterminated string literal");
                }

                const lexeme = self.source[start..self.cursor];
                self.advance(); // eat the "

                return self.newToken(.string, lexeme);
            },
        }
    }

    fn advance(self: *Self) void {
        self.cursor += 1;
        self.cur_col += 1;
    }

    fn isAtEnd(self: *Self) bool {
        return self.cursor >= self.source.len;
    }

    fn cur(self: *Self) u8 {
        return self.source[self.cursor];
    }

    fn peek(self: *Self) u8 {
        if (self.cursor + 1 >= self.source.len) {
            return 0;
        }

        return self.source[self.cursor + 1];
    }

    fn errorToken(self: *Self, message: []const u8) tokens.Token {
        return self.newToken(.@"error", message);
    }

    fn newToken(self: *Self, kind: tokens.TokenKind, lexeme: []const u8) tokens.Token {
        return .{
            .kind = kind,
            .lexeme = lexeme,
            .span = .{
                .column_start = self.prev_col,
                .column_end = self.cur_col,

                .line_start = self.prev_line,
                .line_end = self.cur_line,
            },
        };
    }
};
