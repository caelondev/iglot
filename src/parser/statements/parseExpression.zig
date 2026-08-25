const std = @import("std");
const ast = @import("../ast.zig");
const literal = @import("../nud/literals.zig");
const p = @import("../parser.zig");
const tokens = @import("../../lexer/tokens.zig");
const CiscoParser = p.CiscoParser;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseExpression(parser: *CiscoParser, allocator: std.mem.Allocator, precedence: Precedence) !?ast.Expression {
    const nud = lookupNud(parser.cur_tok.kind) orelse return null;
    var left = try nud(parser, allocator) orelse return null;

    while (precedence.toInt() < Precedence.ofToken(parser.cur_tok).toInt()) {
        const led = lookupLed(parser.cur_tok.kind) orelse break;
        left = try led(parser, allocator, left) orelse return left;
    }

    return left;
}

fn lookupNud(token_kind: tokens.TokenKind) ?p.NudFn {
    const nuds = p.nud_exprs;

    for (nuds) |n| {
        if (n.token_kind == token_kind) return n.callback;
    }

    return null;
}

fn lookupLed(token_kind: tokens.TokenKind) ?p.LedFn {
    const leds = p.led_exprs;

    for (leds) |l| {
        if (l.token_kind == token_kind) return l.callback;
    }

    return null;
}
