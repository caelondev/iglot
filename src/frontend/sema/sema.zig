//! TODO: evalConstInt should distinguish why it failed, instead of returning null for everything
//! - add kinds: ArraySizeOverflow, ArraySizeDivByZero
//! - resolveArraySize maps each variant to its own diagnostic

const std = @import("std");
const IglotDiagnostic = @import("../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("type_table.zig");
const ast = @import("../parser/ast.zig");
const typed_ast = @import("typed_ast.zig");
const Span = @import("../lexer/tokens.zig").Span;

const lookupBuiltin = @import("../../vm/builtins.zig").lookupBuiltin;
const builtins_table = @import("../../vm/builtins.zig").table;

const validateBinaryExpr = @import("expressions/validate_binary_expr.zig").validateBinaryExpr;
const validateUnaryExpr = @import("expressions/validate_unary_expr.zig").validateUnaryExpr;
const validateAssignmentExpr = @import("expressions/validate_assignment_expr.zig").validateAssignmentExpr;
const validateArrayExpr = @import("expressions/validate_array_expr.zig").validateArrayExpr;

const validateFunctionDeclaration = @import("statements/validate_function_declaration.zig").validateFunctionDeclaration;
const validateVariableDeclaration = @import("statements/validate_variable_declaration_expr.zig").validateVariableDeclaration;
const validateReturnStatement = @import("statements/validate_return_statement.zig").validateReturnStatement;
const validateIfStatement = @import("statements/validate_if_statement.zig").validateIfStatement;
const validateCallExpr = @import("expressions/validate_call_expr.zig").validateCallExpr;
const validateLoopStatement = @import("statements/validate_loop_statement.zig").validateLoopStatement;
const validateBreakStatement = @import("statements/validate_break_stmt.zig").validateBreakStatement;

const FunctionContext = struct {
    return_type: tt.SemaType,
};

pub const IglotSemanticAnalyzer = struct {
    type_table: tt.TypeTable,
    diagnostics: std.ArrayList(IglotDiagnostic),

    current_function_ctx: ?FunctionContext,
    loop_depth: usize,

    const Self = @This();
    pub fn init() Self {
        return Self{
            .type_table = undefined,
            .diagnostics = .empty,
            .current_function_ctx = null,
            .loop_depth = 0,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.type_table.deinit(allocator);
        self.diagnostics.deinit(allocator);
    }

    pub fn analyze(self: *Self, allocator: std.mem.Allocator, program: ast.Program) !typed_ast.TypedProgram {
        self.type_table = try .init(allocator);
        try self.initBuiltinIdentifiers(allocator);

        for (program.body) |*s| {
            try self.hoistDeclaration(allocator, s) orelse continue;
        }

        var body: std.ArrayList(typed_ast.TypedStmt) = .empty;
        for (program.body) |*stmt| {
            const typed = try self.scanTopLevelStatement(allocator, stmt) orelse continue;
            try body.append(allocator, typed);
        }
        return .{ .body = try body.toOwnedSlice(allocator) };
    }

    pub fn functionSemType(sema: *Self, allocator: std.mem.Allocator, f: *const ast.FunctionDeclarationStatement) !?tt.SemaType {
        const ret_ptr = try allocator.create(tt.SemaType);
        ret_ptr.* = try tt.SemaType.fromTypeExpression(sema, allocator, f.return_type) orelse return null;

        const params = try allocator.alloc(*tt.SemaType, f.parameters.len);
        for (f.parameters, 0..) |param, i| {
            const p = try allocator.create(tt.SemaType);
            p.* = try tt.SemaType.fromTypeExpression(sema, allocator, param.param_type) orelse return null;
            params[i] = p;
        }

        return .{ .function = .{
            .parameters = params,
            .return_type = ret_ptr,
        } };
    }

    fn hoistDeclaration(self: *Self, allocator: std.mem.Allocator, stmt: *ast.Statement) !?void {
        switch (stmt.kind) {
            .function_decl => |*f| {
                if (self.type_table.lookupCurrentScope(f.identifier.value)) |existing| {
                    const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
                        .{
                            .note = .{
                                .message = "identifier declared here",
                                .span = existing.span,
                            },
                        },
                    });

                    try self.reportError(allocator, .{
                        .span = f.span,
                        .severity = .err,
                        .kind = .{
                            .IdentifierAlreadyExist = .{
                                .identifier = f.identifier.value,
                            },
                        },
                        .annotations = annotations,
                    });

                    return null;
                }

                const function_sem_type = try functionSemType(self, allocator, f) orelse return null;
                try self.type_table.declareIdentifier(allocator, f.identifier.value, .{
                    .span = f.span,
                    .sem_type = function_sem_type,
                    .is_final = false,
                });
            },
            else => return,
        }
    }

    fn scanTopLevelStatement(self: *Self, allocator: std.mem.Allocator, stmt: *const ast.Statement) !?typed_ast.TypedStmt {
        switch (stmt.kind) {
            .variable_declaration => |*v| {
                const decl = try validateVariableDeclaration(self, allocator, v) orelse return null;
                return .{
                    .variable_declaration = decl,
                };
            },
            .function_decl => |f| {
                const decl = try validateFunctionDeclaration(self, allocator, &f) orelse return null;

                if (std.mem.eql(u8, decl.identifier.value, "main")) {
                    try self.validateMainFunctionSigniture(allocator, decl) orelse return null;
                }
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

        for (builtins_table) |b| {
            try self.type_table.declareIdentifier(allocator, b.name, .{
                .sem_type = try b.semaType(allocator),
                .span = .empty(),
                .is_final = true,
                .is_builtin = true,
            });
        }
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
            .variable_declaration => |*v| {
                const decl = try validateVariableDeclaration(self, allocator, v) orelse return null;
                return .{
                    .variable_declaration = decl,
                };
            },
            .if_stmt => |f| {
                const if_stmt = try validateIfStatement(self, allocator, &f) orelse return null;
                return .{
                    .if_stmt = if_stmt,
                };
            },
            .loop => |l| {
                const loop = try validateLoopStatement(self, allocator, &l) orelse return null;
                return .{
                    .loop = loop,
                };
            },
            .scoped => |s| {
                const scoped = try self.validateScopedStatement(allocator, &s) orelse return null;
                return .{ .scoped = scoped };
            },
            .break_stmt => |b| {
                const st = try validateBreakStatement(self, allocator, &b) orelse return null;
                return .{ .break_stmt = st };
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

    pub fn validateScopedStatement(
        self: *Self,
        allocator: std.mem.Allocator,
        scoped: *const ast.ScopedStatement,
    ) anyerror!?typed_ast.TypedScopedStatement {
        var stmts: std.ArrayList(typed_ast.TypedStmt) = .empty;

        for (scoped.statements) |*stmt| {
            const typed = try self.validateStatement(allocator, stmt) orelse continue;
            try stmts.append(allocator, typed);
        }

        return .{
            .typed_stmts = try stmts.toOwnedSlice(allocator),
        };
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
                const sem_type = self.resolveFloatType(f.value, expected_type);
                const node = try allocator.create(typed_ast.TypedExpr);
                node.* = .{ .span = span, .sem_type = sem_type, .kind = .{ .float = f } };
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
            .binary => |*b| validateBinaryExpr(self, allocator, b, span, expected_type),
            .unary => |*u| validateUnaryExpr(self, allocator, u, span, expected_type),
            .assignment => |*a| validateAssignmentExpr(self, allocator, a, span),
            .array => |*a| validateArrayExpr(self, allocator, a, span),
            .call => |*c| validateCallExpr(self, allocator, c, span),
        };
    }

    fn validateMainFunctionSigniture(self: *Self, allocator: std.mem.Allocator, decl: typed_ast.TypedFunctionDeclarationStatement) !?void {
        if (decl.return_type != .void) {
            try self.reportError(allocator, .{
                .kind = .{ .NonVoidMainReturnType = .{ .found = decl.return_type } },
                .span = decl.span,
            });
        }
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
            const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
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

    fn resolveFloatType(self: *Self, value: f64, expected_type: ?tt.SemaType) tt.SemaType {
        _ = self;
        if (expected_type) |t| {
            if (t == .float or t == .double) return t;
        }

        if (value < -std.math.floatMax(f32) or value > std.math.floatMax(f32)) {
            return .double;
        }

        return .float;
    }

    pub fn resolveArraySize(
        self: *Self,
        allocator: std.mem.Allocator,
        e: *const ast.Expression,
        span: Span,
    ) !tt.SemaArraySize {
        const n = try self.evalConstInt(e) orelse {
            // const annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
            //     .{
            //         .help = .{
            //             .message = "array sizes are evaluated at compile time. use literals, arithmetic on them, or `const` identifiers with a constant initializer",
            //         },
            //     },
            // });

            try self.reportError(allocator, .{
                .span = span,
                .kind = .ArraySizeNotConstant,
                .annotations = &.{},
            });
            return .unknown;
        };

        if (n < 0 or n > std.math.maxInt(u64)) {
            try self.reportError(allocator, .{
                .span = span,
                .kind = .{ .InvalidArraySize = .{ .value = n } },
            });
            return .unknown;
        }

        return .{ .known = @intCast(n) };
    }

    pub fn evalConstInt(self: *Self, e: *const ast.Expression) !?i128 {
        return switch (e.expr) {
            .integer => |v| v.value,
            .identifier => @panic("TODO: const variables"),
            .binary => |b| blk: {
                const l = try self.evalConstInt(b.left) orelse break :blk null;
                const r = try self.evalConstInt(b.right) orelse break :blk null;
                break :blk switch (b.operator) {
                    .plus => std.math.add(i128, l, r) catch null,
                    .minus => std.math.sub(i128, l, r) catch null,
                    .asterisk => std.math.mul(i128, l, r) catch null,
                    .slash => if (r == 0) null else @divTrunc(l, r),
                    else => null,
                };
            },
            .unary => |b| blk: {
                const v = try self.evalConstInt(b.rhs) orelse break :blk null;
                break :blk switch (b.operator) {
                    .minus => -v,
                    else => null,
                };
            },

            .wide_integer,
            .float,
            .string,
            .assignment,
            .call,
            .array,
            => null,
        };
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: IglotDiagnostic) !void {
        try self.diagnostics.append(allocator, diagnostic);
    }
};
