const ast = @import("../parser/ast.zig");
const tt = @import("type_table.zig");
const tokens = @import("../lexer/tokens.zig");

pub const TypedExpr = struct {
    span: tokens.Span,
    sem_type: tt.SemaType,
    kind: union(enum) {
        integer: ast.IntegerExpression,
        float: ast.FloatExpression,
        string: ast.StringExpression,
        identifier: ast.IdentifierExpression,

        binary: struct {
            left: *TypedExpr,
            right: *TypedExpr,
            operator: tokens.TokenKind,
        },
        unary: struct {
            rhs: *TypedExpr,
            operator: tokens.TokenKind,
        },
        variable_declaration: struct {
            identifier: ast.IdentifierExpression,
            value: *TypedExpr,
        },
    },
};

pub const TypedStmt = union(enum) {
    expression: struct {
        typed: *TypedExpr,
    },
};

pub const TypedProgram = struct {
    body: []TypedStmt,
};
