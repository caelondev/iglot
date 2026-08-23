const tokens = @import("tokens.zig");

pub const CiscoLexer = struct {
    source: [:0]const u8,
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
    pub fn init(source: [:0]const u8) Self {
        return .{
            .source = source,
            .cursor = 0,

            .prev_col = 0,
            .cur_col = 0,

            .prev_line = 1,
            .cur_line = 1,
        };
    }

    pub fn nextToken(self: *Self) tokens.Token {
        var start = self.cursor;

        lexer: switch (State.start) {
            .start => {
                if (self.isAtEnd()) {
                    return self.newToken(.eof, "END_OF_FILE");
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
                                        self.prev_col = 0;
                                        self.cur_col = 0;
                                        self.cur_line += 1;
                                    }

                                    self.advance();
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
                        self.advance();
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
                        const tok = self.newToken(.illegal, &.{self.cur()});
                        self.advance();
                        return tok;
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
                        'a'...'z', 'A'...'Z', '_', '0'...'9' => {
                            self.advance();
                        },

                        else => break,
                    }
                }

                const lexeme = self.source[start..self.cursor];
                return self.newToken(.number, lexeme);
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
