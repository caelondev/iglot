const tokens = @import("../lexer/tokens.zig");

pub const CiscoDiagnostic = struct {
    span: tokens.Span,
    kind: Kind,

    const Kind = enum {
        IntegerOverflow,
        MissingRightHandSideExpression,
    };
};
