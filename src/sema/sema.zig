const std = @import("std");
const FaruDiagnostic = @import("../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("type_table.zig");
const ast = @import("../parser/ast.zig");
const typed_ast = @import("typed_ast.zig");
const Span = @import("../lexer/tokens.zig").Span;

const validateBinaryExpr = @import("expressions/validate_binary_expr.zig").validateBinaryExpr;
const validateVariableDeclaration = @import("expressions/validate_variable_declaration_expr.zig").validateVariableDeclaration;
const validateUnaryExpr = @import("expressions/validate_unary_expr.zig").validateUnaryExpr;
const validateAssignmentExpr = @import("expressions/validate_assignment_expr.zig").validateAssignmentExpr;
const validateFunctionDeclaration = @import("statements/validate_function_declaration.zig").validateFunctionDeclaration;
const validateReturnStatement = @import("statements/validate_return_statement.zig").validateReturnStatement;
const validateIfStatement = @import("statements/validate_if_statement.zig").validateIfStatement;
const validateCallExpr = @import("expressions/validate_call_expr.zig").validateCallExpr;

const FunctionContext = struct {
    return_type: tt.SemaType,
};

pub const FaruSemanticAnalyzer = struct {
    type_table: tt.TypeTable,
    diagnostics: std.ArrayList(FaruDiagnostic),

    current_function_ctx: ?FunctionContext,

    const Self = @This();
    pub fn init() Self {
        return Self{
            .type_table = undefined,
            .diagnostics = .empty,
            .current_function_ctx = null,
        };
    }

    pub fn analyze(self: *Self, allocator: std.mem.Allocator, program: ast.Program) !typed_ast.TypedProgram {
        self.type_table = try .init(allocator);
        try self.initBuiltinIdentifiers(allocator);

        var body: std.ArrayList(typed_ast.TypedStmt) = .empty;
        for (program.body) |*stmt| {
            const typed = try self.scanTopLevelStatement(allocator, stmt) orelse continue;
            try body.append(allocator, typed);
        }
        return .{ .body = try body.toOwnedSlice(allocator) };
    }

    fn scanTopLevelStatement(self: *Self, allocator: std.mem.Allocator, stmt: *const ast.Statement) !?typed_ast.TypedStmt {
        switch (stmt.kind) {
            .expression => |*e| {
                const expr = try self.validateExpression(allocator, &e.expression, e.span, null) orelse return null;
                if (expr.kind != .variable_declaration) {
                    try self.reportError(allocator, .{
                        .kind = .IllegalTopLevelStatement,
                        .span = stmt.span,
                    });
                }

                return .{
                    .expression = .{ .typed = expr },
                };
            },
            .function_decl => |f| {
                const decl = try validateFunctionDeclaration(self, allocator, &f) orelse return null;
                return .{
                    .function_decl = decl,
                };
            },
            else => {
                try self.reportError(allocator, .{
                    .kind = .IllegalTopLevelStatement,
                    .span = stmt.span,
                });

                return null;
            },
        }
    }

    pub fn initBuiltinIdentifiers(self: *Self, allocator: std.mem.Allocator) !void {
        try self.type_table.declareIdentifier(allocator, "true", .{ .span = Span.empty(), .sem_type = .bool, .is_final = true });
        try self.type_table.declareIdentifier(allocator, "false", .{ .span = Span.empty(), .sem_type = .bool, .is_final = true });
    }

    pub fn validateStatement(self: *Self, allocator: std.mem.Allocator, stmt: *const ast.Statement) !?typed_ast.TypedStmt {
        switch (stmt.kind) {
            .expression => |*e| {
                const expr = try self.validateExpression(allocator, &e.expression, e.span, null) orelse return null;
                return .{
                    .expression = .{ .typed = expr },
                };
            },
            .function_decl => {
                try self.reportError(allocator, .{
                    .kind = .NestedFunctionDeclaration,
                    .span = stmt.span,
                });

                return null;
            },
            .return_stmt => |r| {
                const ret_stmt = try validateReturnStatement(self, allocator, &r) orelse return null;
                return .{
                    .return_stmt = ret_stmt,
                };
            },
            .if_stmt => |f| {
                const if_stmt = try validateIfStatement(self, allocator, &f) orelse return null;
                return .{
                    .if_stmt = if_stmt,
                };
            },
            .scoped => |f| {
                var stmts: std.ArrayList(typed_ast.TypedStmt) = .empty;

                for (f.statements) |*s| {
                    const t_stmt = try self.validateStatement(allocator, s) orelse continue;
                    try stmts.append(allocator, t_stmt);
                }

                return .{ .scoped = .{ .typed_stmts = try stmts.toOwnedSlice(allocator) } };
            },
        }
    }

    pub fn validateBlockStatement(self: *Self, allocator: std.mem.Allocator, block: *const ast.BlockStatement) !?typed_ast.TypedBlockStatement {
        var stmts: std.ArrayList(typed_ast.TypedStmt) = .empty;

        for (block.statements) |*stmt| {
            const t_stmt = try self.validateStatement(allocator, stmt) orelse continue;
            try stmts.append(allocator, t_stmt);
        }

        return .{ .typed_stmts = try stmts.toOwnedSlice(allocator) };
    }

    pub fn validateExpression(
        self: *Self,
        allocator: std.mem.Allocator,
        expr: *const ast.Expression,
        span: Span,
        expected_type: ?tt.SemaType,
    ) !?*typed_ast.TypedExpr {
        return switch (expr.expr) {
            .float => |f| blk: {
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = .float, .kind = .{ .float = f } };
                break :blk node;
            },
            .integer => |i| blk: {
                const sem_type = try self.resolveIntegerType(allocator, i.value, span, expected_type) orelse return null;
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = sem_type, .kind = .{ .integer = i } };
                break :blk node;
            },
            .wide_integer => |i| blk: {
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = .wideint, .kind = .{ .wide_integer = i } };
                break :blk node;
            },
            .string => |s| blk: {
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = .string, .kind = .{ .string = s } };
                break :blk node;
            },
            .identifier => |i| blk: {
                const ident_type = self.type_table.lookupIdentifier(i.value) orelse {
                    try self.reportError(allocator, .{
                        .span = span,
                        .kind = .{ .UndefinedIdentifier = .{ .identifier = i.value } },
                    });
                    return null;
                };
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{
                    .span = span,
                    .sem_type = ident_type.sem_type,
                    .kind = .{
                        .identifier = .{ .value = i.value, .is_final = ident_type.is_final },
                    },
                };
                break :blk node;
            },
            .binary => |*b| validateBinaryExpr(self, allocator, b, span),
            .variable_declaration => |*v| validateVariableDeclaration(self, allocator, v),
            .unary => |*u| validateUnaryExpr(self, allocator, u, span),
            .assignment => |*a| validateAssignmentExpr(self, allocator, a, span),
            .call => |*c| validateCallExpr(self, allocator, c, span),
        };
    }

    fn resolveIntegerType(
        self: *Self,
        allocator: std.mem.Allocator,
        value: i128,
        span: Span,
        expected_type: ?tt.SemaType,
    ) !?tt.SemaType {
        if (expected_type) |t| {
            if (t == .wideint or t == .int) return t;
        }

        if (value < std.math.minInt(i64) or value > std.math.maxInt(i64)) {
            const annotations = try allocator.dupe(FaruDiagnostic.Annotation, &.{
                .{
                    .help = .{
                        .message = "consider using a wideint by suffixing the literal with 'w' or using the \"wideint\" type",
                    },
                },
            });

            try self.reportError(allocator, .{
                .span = span,
                .severity = .err,
                .kind = .IntegerOverflow,
                .annotations = annotations,
            });
            return null;
        }

        return .int;
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: FaruDiagnostic) !void {
        try self.diagnostics.append(allocator, diagnostic);
    }
};
