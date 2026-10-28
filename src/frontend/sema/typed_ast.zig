const ast = @import("../../frontend/parser/ast.zig");
const tt = @import("type_table.zig");
const tokens = @import("../lexer/tokens.zig");

pub const TypedProgram = struct {
    body: []TypedStmt,
};

pub const TypedStmt = union(enum) {
    expression: TypedExpressionStmt,
    function_decl: TypedFunctionDeclarationStatement,
    return_stmt: TypedReturnStatement,
    block: TypedBlockStatement,
    scoped: TypedScopedStatement,
    if_stmt: TypedIfStatement,
    variable_declaration: TypedVariableDeclaration,
    loop: TypedLoopStatement,
    break_stmt: ast.BreakStatement,
};

pub const TypedExpressionStmt = struct {
    typed: *TypedExpr,
};

pub const TypedIdentifier = struct {
    value: []const u8,
    mutability: ast.TypeExpression.Mutability,
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
    sema_type: tt.SemaType,
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
        wide_integer: ast.WideIntegerExpression,
        float: ast.FloatExpression,
        string: ast.StringExpression,
        identifier: TypedIdentifier,
        binary: TypedBinaryExpr,
        unary: TypedUnaryExpr,
        assignment: TypedAssignment,
        call: TypedCallExpr,
        array: TypedArrayExpr,
    },
};

pub const TypedCallExpr = struct {
    callee: *TypedExpr,
    arguments: []*TypedExpr,
    sema_type: tt.SemaType,
};

pub const TypedArrayExpr = struct {
    elements: []*TypedExpr,
    sema_type: tt.SemaType,
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
    return_value_type: tt.SemaType,
    span: tokens.Span,
};

pub const TypedIfStatement = struct {
    condition: *TypedExpr,
    consequence: *TypedStmt,
    alternative: ?*TypedStmt,
};

pub const TypedScopedStatement = struct {
    typed_stmts: []TypedStmt,
};

pub const TypedLoopStatement = struct {
    body: TypedScopedStatement,
};
