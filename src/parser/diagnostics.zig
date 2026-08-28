const tokens = @import("../lexer/tokens.zig");

pub const CiscoDiagnostic = struct {
    span: tokens.Span,
    severity: Severity = .err,
    kind: Kind,
    annotation: ?Annotation = null,

    pub const Severity = enum {
        err,
        warning,
        note,
    };

    pub const Kind = union(enum) {
        IntegerOverflow,
        MissingRightHandSideExpression,
        InvalidLeftHandSideDeclaration,
        MissingType,

        ExpectedToken: struct {
            expected: tokens.TokenKind,
            found: tokens.TokenKind,
        },
    };

    pub const Annotation = union(enum) {
        note: Note,
        help: Help,
    };

    pub const Note = struct {
        span: ?tokens.Span = null,
        message: []const u8,
    };

    pub const Help = struct {
        message: []const u8,
    };
};
