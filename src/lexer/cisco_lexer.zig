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
                        'a'...'z', 'A'...'Z', '_' => {
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
