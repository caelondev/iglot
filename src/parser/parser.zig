const std = @import("std");

const CiscoLexer = @import("../lexer/cisco_lexer.zig").CiscoLexer;
const tokens = @import("../lexer/tokens.zig");
const ast = @import("ast.zig");
const CiscoDiagnostic = @import("diagnostics.zig").CiscoDiagnostic;

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

const NullDenotedExpr = struct {
    token_kind: tokens.TokenKind,
    callback: NudFn,
};

const LeftDenotedExpr = struct {
    token_kind: tokens.TokenKind,
    callback: LedFn,
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
};

pub const led_exprs = [_]LeftDenotedExpr{
    .{
        .token_kind = .plus,
        .callback = @import("left/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .minus,
        .callback = @import("left/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .slash,
        .callback = @import("left/binary_expression.zig").parseBinaryExpression,
    },
    .{
        .token_kind = .asterisk,
        .callback = @import("left/binary_expression.zig").parseBinaryExpression,
    },
};

pub const CiscoParser = struct {
    lexer: *CiscoLexer,
    cur_tok: tokens.Token,
    peek_tok: tokens.Token,

    diagnostics: std.ArrayList(CiscoDiagnostic),

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
        };
    }

    pub fn parseProgram(self: *Self, allocator: std.mem.Allocator) !ast.Program {
        var stmts: std.ArrayList(ast.Statement) = .empty;

        while (!self.isEof()) {
            const s = parseStatement(self, allocator) catch |e| {
                @panic(@tagName(e));
            };

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
        try self.diagnostics.append(allocator, diagnostic);
    }

    pub fn cur_precedence(self: *Self) Precedence {
        return .ofToken(self.cur_tok);
    }
};
