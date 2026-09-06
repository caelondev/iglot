const std = @import("std");
const ast = @import("../ast.zig");
const CiscoParser = @import("../parser.zig").CiscoParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const parseTypeExpression = @import("../type/parse_type_expression.zig").parseTypeExpression;
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseVariableDeclaration(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
    left: ast.Expression,
) !?ast.Expression {
    // NOTE: this check is super important. since the declaration is an expression,
    // the precedence also mess with the main pratt parser. without checking if
    // left is not an identifier, the parser will recurse indefinitely
    if (left.expr != .identifier) {
        try parser.reportError(allocator, .{
            .span = left.span,
            .kind = .InvalidLeftHandSideDeclaration,
        });
        parser.synchronize();
        return null;
    }

    parser.nextToken();

    const decl_type = try parseTypeExpression(parser, allocator) orelse return null;

    if (!try parser.expectPeek(allocator, .assign)) return null;
    parser.nextToken();

    const value = try parseExpression(
        parser,
        allocator,
        Precedence.lowest.toInt(),
    ) orelse return null;

    const val_ptr = try allocator.create(ast.Expression);
    val_ptr.* = value;

    const span = Span.mergeFromSpans(left.span, value.span);

    return .{
        .span = span,
        .expr = .{
            .variable_declaration = .{
                .identifier = left.expr.identifier,
                .type = decl_type,
                .value = val_ptr,
                .span = span,
            },
        },
    };
}
