const ast = @import("../parser/ast.zig");
const tt = @import("type_table.zig");
const tokens = @import("../lexer/tokens.zig");

pub const TypedProgram = struct {
    body: []TypedStmt,
};

pub const TypedStmt = union(enum) {
    expression: TypedExpressionStmt,
    function_decl: TypedFunctionDeclarationStatement,
    return_stmt: TypedReturnStatement,
};

pub const TypedExpressionStmt = struct {
    typed: *TypedExpr,
};

pub const TypedIdentifier = struct {
    value: []const u8,
    is_final: bool,
};

pub const TypedBinaryExpr = struct {
    left: *TypedExpr,
    right: *TypedExpr,
    operator: tokens.TokenKind,
};

pub const TypedUnaryExpr = struct {
    rhs: *TypedExpr,
    operator: tokens.TokenKind,
};

pub const TypedVariableDeclaration = struct {
    identifier: ast.IdentifierExpression,
    value: *TypedExpr,
};

pub const TypedAssignment = struct {
    assignee: *TypedExpr,
    value: *TypedExpr,
};

pub const TypedExpr = struct {
    span: tokens.Span,
    sem_type: tt.SemaType,
    kind: union(enum) {
        integer: ast.IntegerExpression,
        float: ast.FloatExpression,
        string: ast.StringExpression,
        identifier: TypedIdentifier,
        binary: TypedBinaryExpr,
        unary: TypedUnaryExpr,
        variable_declaration: TypedVariableDeclaration,
        assignment: TypedAssignment,
    },
};

pub const TypedFunctionParameter = struct {
    identifier: ast.IdentifierExpression,
    param_type: tt.SemaType,
    span: tokens.Span,
};

pub const TypedBlockStatement = struct {
    typed_stmts: []TypedStmt,
};

pub const TypedFunctionDeclarationStatement = struct {
    identifier: ast.IdentifierExpression,
    parameters: []TypedFunctionParameter,
    body: TypedBlockStatement,
    return_type: tt.SemaType,
    span: tokens.Span,
};

pub const TypedReturnStatement = struct {
    return_value: ?*TypedExpr,
    span: tokens.Span,
};
