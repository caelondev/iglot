const std = @import("std");
const CiscoDiagnostic = @import("../diagnostics/diagnostics.zig").CiscoDiagnostic;
const tt = @import("type_table.zig");
const ast = @import("../parser/ast.zig");
const typed_ast = @import("typed_ast.zig");
const Span = @import("../lexer/tokens.zig").Span;

const validateBinaryExpression = @import("expressions/validate_binary_expr.zig").validateBinaryExpr;
const validateVariableDeclaration = @import("expressions/validate_variable_declaration_expr.zig").validateVariableDeclaration;
const validateUnaryExpression = @import("expressions/validate_unary_expr.zig").validateUnaryExpr;
const validateAssignmentExpression = @import("expressions/validate_assignment_expr.zig").validateAssignmentExpr;
const validateFunctionDeclaration = @import("statements/validate_function_declaration.zig").validateFunctionDeclaration;

pub const CiscoSemanticAnalyzer = struct {
    type_table: tt.TypeTable,
    diagnostics: std.ArrayList(CiscoDiagnostic),

    const Self = @This();
    pub fn init() Self {
        return Self{
            .type_table = undefined,
            .diagnostics = .empty,
        };
    }

    pub fn analyze(self: *Self, allocator: std.mem.Allocator, program: ast.Program) !typed_ast.TypedProgram {
        self.type_table = try .init(allocator);
        try self.initBuiltinIdentifiers(allocator);

        var body: std.ArrayList(typed_ast.TypedStmt) = .empty;
        for (program.body) |*stmt| {
            const typed = try self.validateStatement(allocator, stmt) orelse continue;
            try body.append(allocator, typed);
        }
        return .{ .body = try body.toOwnedSlice(allocator) };
    }

    pub fn initBuiltinIdentifiers(self: *Self, allocator: std.mem.Allocator) !void {
        try self.type_table.declareIdentifier(allocator, "true", .{ .span = Span.empty(), .sem_type = .bool, .is_final = true });
        try self.type_table.declareIdentifier(allocator, "false", .{ .span = Span.empty(), .sem_type = .bool, .is_final = true });
    }

    pub fn validateStatement(self: *Self, allocator: std.mem.Allocator, stmt: *const ast.Statement) !?typed_ast.TypedStmt {
        switch (stmt.*) {
            .expression => |*e| {
                const expr = try self.validateExpression(allocator, &e.expression, e.span) orelse return null;
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
        }
    }

    pub fn validateBlockStatement(self: *Self, allocator: std.mem.Allocator, block: *const ast.BlockStatement) !?typed_ast.TypedBlockStatement {
        var stmts: std.ArrayList(typed_ast.TypedStmt) = .empty;

        for (block.statements) |*stmt| {
            const t_stmt = try self.validateStatement(allocator, stmt) orelse return null;
            try stmts.append(allocator, t_stmt);
        }

        return .{ .typed_stmts = try stmts.toOwnedSlice(allocator) };
    }

    pub fn validateExpression(self: *Self, allocator: std.mem.Allocator, expr: *const ast.Expression, span: Span) !?*typed_ast.TypedExpr {
        return switch (expr.expr) {
            .float => |f| blk: {
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = .float, .kind = .{ .float = f } };
                break :blk node;
            },
            .integer => |i| blk: {
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = .int, .kind = .{ .integer = i } };
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
            .binary => |*b| validateBinaryExpression(self, allocator, b, span),
            .variable_declaration => |*v| validateVariableDeclaration(self, allocator, v),
            .unary => |*u| validateUnaryExpression(self, allocator, u, span),
            .assignment => |*a| validateAssignmentExpression(self, allocator, a, span),
        };
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: CiscoDiagnostic) !void {
        try self.diagnostics.append(allocator, diagnostic);
    }
};
