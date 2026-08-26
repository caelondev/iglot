const tokens = @import("../lexer/tokens.zig");

pub const CiscoDiagnostic = struct {
    span: tokens.Span,
    kind: Kind,

    const Kind = union(enum) {
        IntegerOverflow,
        MissingRightHandSideExpression,
        ExpectedToken: struct {
            expected: tokens.TokenKind,
            found: tokens.TokenKind,
        },
    };
};
