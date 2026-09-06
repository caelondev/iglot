const std = @import("std");

const CiscoLexer = @import("../lexer/cisco_lexer.zig").CiscoLexer;
const tokens = @import("../lexer/tokens.zig");
const ast = @import("ast.zig");
const CiscoDiagnostic = @import("../diagnostics/diagnostics.zig").CiscoDiagnostic;

const nud_lit = @import("nud/literals.zig");
const parseStatement = @import("statements/parseStatement.zig").parseStatement;
const Precedence = @import("precedence.zig").Precedence;

pub const NudFn = *const fn (
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) anyerror!?ast.Expression;

pub const LedFn = *const fn (
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) anyerror!?ast.Expression;

pub const StmtFn = *const fn (
    parser: *CiscoParser,
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
        .token_kind = .minus,
        .callback = @import("nud/unary_expression.zig").parseUnaryExpression,
    },
    .{
        .token_kind = .bang,
        .callback = @import("nud/unary_expression.zig").parseUnaryExpression,
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
        .token_kind = .box_colon,
        .callback = @import("led/parse_variable_declaration.zig").parseVariableDeclaration,
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
};

pub const statements = [_]Statement{
    .{
        .token_kind = .@"fn",
        .callback = @import("statements/function_declaration.zig").parseFunctionDeclarationStatement,
    },
    .{
        .token_kind = .@"return",
        .callback = @import("statements/return_statement.zig").parseReturnStatement,
    },
};

pub const CiscoParser = struct {
    lexer: *CiscoLexer,
    cur_tok: tokens.Token,
    peek_tok: tokens.Token,

    diagnostics: std.ArrayList(CiscoDiagnostic),
    panic_mode: bool,
    advance_count: u32,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        lexer: *CiscoLexer,
    ) !Self {
        var p: Self = .{
            .lexer = lexer,
            .cur_tok = undefined,
            .peek_tok = undefined,
            .diagnostics = try .initCapacity(allocator, 15),
            .panic_mode = false,
            .advance_count = 0,
        };

        // fill up cur_tok and peek_tok
        p.nextToken();
        p.nextToken();

        return p;
    }

    pub fn parseProgram(self: *Self, allocator: std.mem.Allocator) !ast.Program {
        var stmts: std.ArrayList(ast.Statement) = .empty;

        while (!self.curTokenIs(.eof)) {
            if (try parseStatement(self, allocator)) |stmt| {
                try stmts.append(allocator, stmt);
            }
            self.nextToken();
        }

        const body = try stmts.toOwnedSlice(allocator);
        return .{ .body = body };
    }

    pub fn nextToken(self: *Self) void {
        self.cur_tok = self.peek_tok;
        self.peek_tok = self.lexer.nextToken();
        self.advance_count += 1;
    }

    pub fn curTokenIs(self: *Self, kind: tokens.TokenKind) bool {
        return self.cur_tok.kind == kind;
    }

    pub fn peekTokenIs(self: *Self, kind: tokens.TokenKind) bool {
        return self.peek_tok.kind == kind;
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

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: CiscoDiagnostic) !void {
        if (self.panic_mode) return;

        self.panic_mode = true;
        try self.diagnostics.append(allocator, diagnostic);
    }

    pub fn curPrecedence(self: *Self) u8 {
        return Precedence.ofToken(self.cur_tok).toInt();
    }

    pub fn synchronize(self: *CiscoParser) void {
        if (!self.panic_mode) return;

        while (self.cur_tok.kind != .eof) {
            switch (self.cur_tok.kind) {
                .semicolon => {
                    self.nextToken();
                    break;
                },

                .right_brace,
                .right_parenthesis,
                .right_bracket,
                => break,

                else => self.nextToken(),
            }
        }

        self.panic_mode = false;
    }
};
