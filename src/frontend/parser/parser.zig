const std = @import("std");

const IglotLexer = @import("../lexer/lexer.zig").IglotLexer;
const tokens = @import("../lexer/tokens.zig");
const ast = @import("ast.zig");
const IglotDiagnostic = @import("../../diagnostics/diagnostics.zig").IglotDiagnostic;

const nud_lit = @import("nud/literals.zig");
const parseStatement = @import("statements/parseStatement.zig").parseStatement;
const parseStatementRecovering = @import("statements/parseStatement.zig").parseStatementRecovering;
const Precedence = @import("precedence.zig").Precedence;

pub const NudFn = *const fn (
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) anyerror!?ast.Expression;

pub const LedFn = *const fn (
    parser: *IglotParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) anyerror!?ast.Expression;

pub const StmtFn = *const fn (
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) anyerror!?ast.Statement;

const NullDenotedExpr = struct {
    token_kind: tokens.TokenKind,
    callback: NudFn,
};

const LeftDenotedExpr = struct {
    token_kind: tokens.TokenKind,
    callback: LedFn,
};

const Statement = struct {
    token_kind: tokens.TokenKind,
    callback: StmtFn,
};

pub const nud_exprs = [_]NullDenotedExpr{
    .{
        .token_kind = .integer,
        .callback = nud_lit.parseInteger,
    },
    .{
        .token_kind = .wideint,
        .callback = nud_lit.parseWideInteger,
    },
    .{
        .token_kind = .float,
        .callback = nud_lit.parseFloat,
    },
    .{
        .token_kind = .string,
        .callback = nud_lit.parseString,
    },
    .{
        .token_kind = .identifier,
        .callback = nud_lit.parseIdentifier,
    },
    .{
        .token_kind = .left_parenthesis,
        .callback = @import("nud/grouping_expression.zig").parseGroupingExpression,
    },
    .{
        .token_kind = .left_bracket,
        .callback = @import("nud/array_expression.zig").parseArrayExpression,
    },
    .{
        .token_kind = .left_brace,
        .callback = @import("nud/bare_brace_expression.zig").parseBareBraceExpression,
    },
    .{
        .token_kind = .minus,
        .callback = @import("nud/unary_expression.zig").parseUnaryExpression,
    },
    .{
        .token_kind = .bang,
        .callback = @import("nud/unary_expression.zig").parseUnaryExpression,
    },
    .{
        .token_kind = .@"break",
        .callback = @import("nud/break_expression.zig").parseBreakExpression,
    },
    .{
        .token_kind = .@"return",
        .callback = @import("nud/return_expression.zig").parseReturnExpression,
    },
};

pub const led_exprs = [_]LeftDenotedExpr{
    .{
        .token_kind = .plus,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .minus,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .slash,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .asterisk,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .assign,
        .callback = @import("led/assignment_expression.zig").parseAssignmentExpression,
    },
    .{
        .token_kind = .less,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .greater,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .less_equal_to,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .greater_equal_to,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .equal_to,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .not_equal_to,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .@"and",
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .@"or",
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .or_else,
        .callback = @import("led/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .dot_bracket,
        .callback = @import("led/index_expression.zig").parseIndexExpression,
    },
    .{
        .token_kind = .left_parenthesis,
        .callback = @import("led/call_expression.zig").parseCallExpression,
    },
    .{
        .token_kind = .hashtag,
        .callback = @import("led/call_expression.zig").parseCallBuiltinExpression,
    },
    .{
        .token_kind = .dot,
        .callback = @import("led/member_expression.zig").parseMemberExpression,
    },
};

pub const statements = [_]Statement{
    .{
        .token_kind = .@"fn",
        .callback = @import("statements/function_declaration.zig").parseFunctionDeclarationStatement,
    },
    .{
        .token_kind = .@"if",
        .callback = @import("statements/if_statement.zig").parseIfStatement,
    },
    .{
        .token_kind = .loop,
        .callback = @import("statements/loop_statement.zig").parseLoopStatement,
    },
    .{
        .token_kind = .@"struct",
        .callback = @import("statements/struct_declaration.zig").parseStructDeclarationStatement,
    },
    .{
        .token_kind = .@"switch",
        .callback = @import("statements/switch_statement.zig").parseSwitchStatement,
    },
};

pub const IglotParser = struct {
    lexer: *IglotLexer,
    cur_tok: tokens.Token,
    peek_tok: tokens.Token,

    diagnostics: std.ArrayList(IglotDiagnostic),
    panic_mode: bool,
    errors: u32,
    advance_count: u32,
    brace_depth: u32,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        lexer: *IglotLexer,
    ) !Self {
        var p: Self = .{
            .lexer = lexer,
            .cur_tok = undefined,
            .peek_tok = undefined,
            .diagnostics = try .initCapacity(allocator, 15),
            .panic_mode = false,
            .errors = 0,
            .advance_count = 0,
            .brace_depth = 0,
        };

        // fill up cur_tok and peek_tok
        p.nextToken();
        p.nextToken();

        return p;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.diagnostics.deinit(allocator);
    }

    pub fn parseProgram(self: *Self, allocator: std.mem.Allocator) !?ast.Program {
        const header = try self.parseModuleHeader(allocator) orelse return null;

        var imports: std.ArrayList(ast.Import) = .empty;

        while (self.curTokenIs(.import)) {
            if (try self.parseImport(allocator)) |imp| {
                try imports.append(allocator, imp);
            } else {
                self.synchronize(0);
            }
        }

        var stmts: std.ArrayList(ast.Statement) = .empty;

        while (!self.curTokenIs(.eof)) {
            if (try parseStatementRecovering(self, allocator)) |stmt| {
                try stmts.append(allocator, stmt);
            }
        }

        const body = try stmts.toOwnedSlice(allocator);
        return .{
            .module_header = header,
            .imports = try imports.toOwnedSlice(allocator),
            .body = body,
        };
    }

    fn parseModuleHeader(self: *Self, allocator: std.mem.Allocator) !?ast.ModuleHeader {
        if (!self.curTokenIs(.module)) {
            try self.reportError(allocator, .{
                .span = self.cur_tok.span,
                .kind = .{ .ExpectedToken = .{
                    .expected = .module,
                    .found = self.cur_tok.kind,
                } },
            });
            self.synchronize(0);
            return null;
        }
        const module_tok = self.cur_tok;

        if (!try self.expectPeek(allocator, .identifier)) {
            self.synchronize(0);
            return null;
        }
        const name = self.cur_tok.lexeme;

        if (!try self.expectSemicolon(allocator)) {
            self.synchronize(0);
            return null;
        }
        const sc = self.cur_tok;
        self.nextToken();
        return .{
            .span = .mergeFromSpans(module_tok.span, sc.span),
            .name = name,
        };
    }

    fn parseImport(self: *Self, allocator: std.mem.Allocator) !?ast.Import {
        const import_tok = self.cur_tok;

        if (!try self.expectPeek(allocator, .identifier)) return null;
        const first = self.cur_tok;

        var name = first.lexeme;
        var alias: ?[]const u8 = null;

        if (self.peekTokenIs(.box_colon)) {
            self.nextToken();
            if (!try self.expectPeek(allocator, .identifier)) return null;
            alias = first.lexeme;
            name = self.cur_tok.lexeme;
        }

        if (!try self.expectSemicolon(allocator)) return null;
        const sc = self.cur_tok;
        self.nextToken();

        return .{
            .name = name,
            .alias = alias,
            .span = .mergeFromSpans(import_tok.span, sc.span),
        };
    }

    pub fn nextToken(self: *Self) void {
        self.cur_tok = self.peek_tok;
        self.peek_tok = self.lexer.nextToken();
        self.advance_count += 1;

        if (self.advance_count >= 2) switch (self.cur_tok.kind) {
            .left_brace => self.brace_depth += 1,
            .right_brace => self.brace_depth -|= 1,
            else => {},
        };
    }

    pub fn curTokenIs(self: *Self, kind: tokens.TokenKind) bool {
        return self.cur_tok.kind == kind;
    }

    pub fn peekTokenIs(self: *Self, kind: tokens.TokenKind) bool {
        return self.peek_tok.kind == kind;
    }

    pub fn expectSemicolon(self: *Self, allocator: std.mem.Allocator) !bool {
        if (self.peekTokenIs(.semicolon)) {
            self.nextToken();
            return true;
        }

        const span: tokens.Span = .afterTokenSpan(self.cur_tok);
        const diag: IglotDiagnostic = .{
            .span = span,
            .kind = .{ .ExpectedToken = .{
                .expected = .semicolon,
                .found = self.peek_tok.kind,
            } },
        };

        const looks_like_boundary = switch (self.peek_tok.kind) {
            .right_brace, .eof, .identifier, .@"return", .@"break" => true,
            else => isStatementStart(self.peek_tok.kind),
        };

        if (looks_like_boundary) {
            // report, but don't enter panic mode. we'll act like it was there
            if (!self.panic_mode) {
                self.errors += 1;
                try self.diagnostics.append(allocator, diag);
            }
            return true;
        }

        try self.reportError(allocator, diag);
        return false;
    }

    pub fn expectPeek(self: *Self, allocator: std.mem.Allocator, expected_kind: tokens.TokenKind) !bool {
        if (self.peekTokenIs(expected_kind)) {
            self.nextToken();
            return true;
        }

        try self.reportError(allocator, .{
            .span = self.peek_tok.span,
            .kind = .{
                .ExpectedToken = .{
                    .expected = expected_kind,
                    .found = self.peek_tok.kind,
                },
            },
        });

        return false;
    }

    pub fn madeProgress(self: *Self, since: u32) bool {
        return self.advance_count != since;
    }

    pub fn isEof(self: *Self) bool {
        return self.cur_tok.kind == .eof;
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: IglotDiagnostic) !void {
        if (self.panic_mode) return;
        if (diagnostic.severity == .err) {
            self.panic_mode = true;
            self.errors += 1;
        }

        try self.diagnostics.append(allocator, diagnostic);
    }

    pub fn curPrecedence(self: *Self) u8 {
        return Precedence.ofToken(self.cur_tok).toInt();
    }

    fn atStatementStart(self: *Self) bool {
        return switch (self.cur_tok.kind) {
            .@"return", .@"break" => true,

            // var decl
            .identifier => self.peek_tok.kind == .box_colon,
            else => isStatementStart(self.cur_tok.kind),
        };
    }

    pub fn synchronize(self: *Self, start_depth: u32) void {
        if (!self.panic_mode) return;

        while (!self.isEof()) {
            switch (self.cur_tok.kind) {
                .right_brace => if (self.brace_depth < start_depth) break,
                .semicolon => if (self.brace_depth <= start_depth) {
                    self.nextToken();
                    break;
                },
                else => if (self.brace_depth <= start_depth and self.atStatementStart()) break,
            }
            self.nextToken();
        }

        self.panic_mode = false;
    }

    pub fn skipMalformedBody(self: *Self) void {
        while (self.cur_tok.kind != .left_brace and self.cur_tok.kind != .eof) {
            if (isStatementStart(self.peek_tok.kind)) return;
            self.nextToken();
        }
        if (self.cur_tok.kind != .left_brace) return;

        var depth: u32 = 0;
        while (self.cur_tok.kind != .eof) {
            switch (self.cur_tok.kind) {
                .left_brace => depth += 1,
                .right_brace => {
                    depth -= 1;
                    if (depth == 0) {
                        self.nextToken();
                        self.panic_mode = false;
                        return;
                    }
                },
                else => {},
            }
            self.nextToken();
        }
    }

    fn isStatementStart(kind: tokens.TokenKind) bool {
        for (statements) |stmt| {
            if (stmt.token_kind == kind) return true;
        }
        return false;
    }

    pub fn peekIsStatementStart(self: *Self) bool {
        return isStatementStart(self.peek_tok.kind);
    }

    pub fn peekIs(self: *Self, kind: tokens.TokenKind) bool {
        return self.peek_tok.kind == kind;
    }
};
