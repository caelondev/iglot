const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("../statements/parseExpression.zig").parseExpression;
const parseTypeExpression = @import("../type/parse_type_expression.zig").parseTypeExpression;
const Span = @import("../../lexer/tokens.zig").Span;
const Precedence = @import("../precedence.zig").Precedence;

pub fn parseVariableDeclaration(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const var_name = parser.cur_tok;
    parser.nextToken();

    var decl_type: ?ast.TypeExpression = null;
    if (!parser.peekIs(.assign)) {
        parser.nextToken();
        decl_type = try parseTypeExpression(parser, allocator) orelse return null;
    }

    if (!try parser.expectPeek(allocator, .assign)) return null;
    parser.nextToken();

    const value = try parseExpression(
        parser,
        allocator,
        Precedence.lowest.toInt(),
    ) orelse return null;

    if (!try parser.expectPeek(allocator, .semicolon)) return null;

    const val_ptr = try allocator.create(ast.Expression);
    val_ptr.* = value;

    const span = Span.mergeFromSpans(var_name.span, value.span);

    return .{
        .span = span,
        .kind = .{
            .variable_declaration = .{
                .identifier = .{ .value = var_name.lexeme },
                .type = decl_type,
                .value = val_ptr,
                .span = span,
            },
        },
    };
}
