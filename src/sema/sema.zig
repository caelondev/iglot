const std = @import("std");
const CiscoDiagnostic = @import("../diagnostics/diagnostics.zig").CiscoDiagnostic;
const tt = @import("type_table.zig");
const ast = @import("../parser/ast.zig");
const Span = @import("../lexer/tokens.zig").Span;

const validateBinaryExpression = @import("expressions/validate_binary_expr.zig").validateBinaryExpr;
const validateVariableDeclaration = @import("expressions/validate_variable_declaration_expr.zig").validateVariableDeclaration;

pub const CiscoSemanticAnalyzer = struct {
    types: tt.TypeTable,
    diagnostics: std.ArrayList(CiscoDiagnostic),

    const Self = @This();
    pub fn init() Self {
        return Self{
            .types = .{ .types = .empty },
            .diagnostics = .empty,
        };
    }

    pub fn analyze(self: *Self, allocator: std.mem.Allocator, program: ast.Program) !void {
        for (program.body) |stmt| {
            try self.validateStatement(allocator, stmt);
        }
    }

    pub fn validateStatement(self: *Self, allocator: std.mem.Allocator, stmt: ast.Statement) !void {
        switch (stmt) {
            .expression => |e| {
                _ = try self.validateExpression(allocator, e.expression, e.span);
            },
        }
    }

    pub fn validateExpression(self: *Self, allocator: std.mem.Allocator, expr: ast.Expression, span: Span) !?tt.SemaType {
        return switch (expr.expr) {
            .float => .float,
            .integer => .int,
            .string => .string,
            .binary => |b| {
                return validateBinaryExpression(self, allocator, b, span);
            },

            .variable_declaration => |v| {
                return validateVariableDeclaration(self, allocator, v);
            },
            else => unreachable,
        };
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: CiscoDiagnostic) !void {
        try self.diagnostics.append(allocator, diagnostic);
    }
};
