const std = @import("std");
const CiscoDiagnostic = @import("../diagnostics/diagnostics.zig").CiscoDiagnostic;
const tt = @import("type_table.zig");
const ast = @import("../parser/ast.zig");
const typed_ast = @import("typed_ast.zig");
const Span = @import("../lexer/tokens.zig").Span;

const validateBinaryExpression = @import("expressions/validate_binary_expr.zig").validateBinaryExpr;
const validateVariableDeclaration = @import("expressions/validate_variable_declaration_expr.zig").validateVariableDeclaration;
const validateUnaryExpression = @import("expressions/validate_unary_expr.zig").validateUnaryExpr;

pub const CiscoSemanticAnalyzer = struct {
    type_table: tt.TypeTable,
    diagnostics: std.ArrayList(CiscoDiagnostic),

    const Self = @This();
    pub fn init() Self {
        return Self{
            .type_table = .{ .types = .empty },
            .diagnostics = .empty,
        };
    }

    pub fn analyze(self: *Self, allocator: std.mem.Allocator, program: ast.Program) !typed_ast.TypedProgram {
        var body: std.ArrayList(typed_ast.TypedStmt) = .empty;
        for (program.body) |*stmt| {
            const typed = try self.validateStatement(allocator, stmt) orelse continue;
            try body.append(allocator, typed);
        }
        return .{ .body = try body.toOwnedSlice(allocator) };
    }

    pub fn validateStatement(self: *Self, allocator: std.mem.Allocator, stmt: *const ast.Statement) !?typed_ast.TypedStmt {
        switch (stmt.*) {
            .expression => |*e| {
                const expr = try self.validateExpression(allocator, &e.expression, e.span) orelse return null;
                return .{
                    .expression = .{ .typed = expr },
                };
            },
        }
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
                const ident_type = self.type_table.lookupIdentifier(i.value) orelse return null;
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = ident_type.sem_type, .kind = .{ .identifier = i } };
                break :blk node;
            },
            .binary => |*b| validateBinaryExpression(self, allocator, b, span),
            .variable_declaration => |*v| validateVariableDeclaration(self, allocator, v),
            .unary => |*u| validateUnaryExpression(self, allocator, u, span),
            else => unreachable,
        };
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: CiscoDiagnostic) !void {
        try self.diagnostics.append(allocator, diagnostic);
    }
};
