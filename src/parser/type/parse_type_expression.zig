const std = @import("std");

const CiscoLexer = @import("../../lexer/cisco_lexer.zig").CiscoLexer;
const tokens = @import("../../lexer/tokens.zig");
const ast = @import("../ast.zig");
const CiscoDiagnostic = @import("../../diagnostics/diagnostics.zig").CiscoDiagnostic;

const nud_lit = @import("../nud/literals.zig");
const parseStatement = @import("../statements/parseStatement.zig").parseStatement;
const Precedence = @import("../precedence.zig").Precedence;
const CiscoParser = @import("../parser.zig").CiscoParser;

pub fn parseTypeExpression(parser: *CiscoParser) ast.TypeExpression {
    return .{ .identifier = parser.advance().lexeme };
}
