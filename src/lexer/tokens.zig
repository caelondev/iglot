pub const TokenKind = enum {
    eof,
    illegal,

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

pub const Span = struct {
    column_start: usize,
    column_end: usize,
    line_start: usize,
    line_end: usize,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    span: Span,
};
