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
};

pub const CiscoParser = struct {
    lexer: *CiscoLexer,
    cur_tok: tokens.Token,
    peek_tok: tokens.Token,

    diagnostics: std.ArrayList(CiscoDiagnostic),
    panic_mode: bool,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        lexer: *CiscoLexer,
    ) !Self {
        const cur_tok = lexer.nextToken();
        const peek_tok = lexer.nextToken();

        return .{
            .lexer = lexer,
            .cur_tok = cur_tok,
            .peek_tok = peek_tok,
            .diagnostics = try .initCapacity(allocator, 15),
            .panic_mode = false,
        };
    }

    pub fn parseProgram(self: *Self, allocator: std.mem.Allocator) !ast.Program {
        var stmts: std.ArrayList(ast.Statement) = .empty;

        while (!self.isEof()) {
            std.debug.print(
                "[parseProgram] cur={} peek={} column_start={} line_start={} panic_mode={}\n",
                .{ self.cur_tok.kind, self.peek_tok.kind, self.cur_tok.span.column_start, self.cur_tok.span.line_start, self.panic_mode },
            );

            const s = try parseStatement(self, allocator);

            if (s) |stmt| {
                try stmts.append(allocator, stmt);
            }
        }

        const body = try stmts.toOwnedSlice(allocator);
        return .{ .body = body };
    }

    pub fn advance(self: *Self) tokens.Token {
        const cur = self.cur_tok;

        self.cur_tok = self.peek_tok;
        self.peek_tok = self.lexer.nextToken();

        return cur;
    }

    pub fn isEof(self: *Self) bool {
        return self.cur_tok.kind == .eof;
    }

    pub fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: CiscoDiagnostic) !void {
        if (self.panic_mode) return;

        self.panic_mode = true;
        try self.diagnostics.append(allocator, diagnostic);
    }

    pub fn cur_precedence(self: *Self) u8 {
        return Precedence.ofToken(self.cur_tok).toInt();
    }

    pub fn expect(self: *Self, allocator: std.mem.Allocator, expected_kind: tokens.TokenKind) !?tokens.Token {
        if (self.cur_tok.kind != expected_kind) {
            try self.reportError(allocator, .{
                .span = self.cur_tok.span,
                .kind = .{
                    .ExpectedToken = .{
                        .expected = expected_kind,
                        .found = self.cur_tok.kind,
                    },
                },
            });

            return null;
        }

        return self.advance();
    }

    pub fn synchronize(self: *CiscoParser) void {
        if (!self.panic_mode) return;

        while (self.cur_tok.kind != .eof) {
            switch (self.cur_tok.kind) {
                .semicolon => {
                    _ = self.advance();
                    break;
                },

                .right_brace,
                .right_parenthesis,
                .right_bracket,
                => break,

                else => {
                    _ = self.advance();
                },
            }
        }

        self.panic_mode = false;
    }
};
