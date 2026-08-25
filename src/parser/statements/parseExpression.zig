const std = @import("std");
const ast = @import("../ast.zig");
const literal = @import("../nud/literals.zig");
const p = @import("../parser.zig");
const tokens = @import("../../lexer/tokens.zig");
const CiscoParser = p.CiscoParser;

pub fn parseExpression(parser: *CiscoParser, allocator: std.mem.Allocator) !?ast.Expression {
    const nud = lookupNud(parser.cur_tok.kind);
    if (nud) |n| {
        const expr = try n(parser, allocator);
        return expr;
    }

    return null;
}

fn lookupNud(token_kind: tokens.TokenKind) ?p.NudFn {
    const nuds = p.nud_exprs;

    for (nuds) |n| {
        if (n.token_kind == token_kind) return n.callback;
    }

    return null;
}
