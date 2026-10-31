const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const parseExpression = @import("parseExpression.zig").parseExpression;
const parseBlockStatement = @import("block_statement.zig").parseBlockStatement;
const pt = @import("../type/parse_type_expression.zig");
const Precedence = @import("../precedence.zig").Precedence;
const tokens = @import("../../lexer/tokens.zig");
const Span = tokens.Span;

pub fn parseStructDeclarationStatement(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {
    const struct_tok = parser.cur_tok;
    if (!try parser.expectPeek(allocator, .identifier)) return null;
    const struct_name = parser.cur_tok;

    if (!try parser.expectPeek(allocator, .colon)) return null;

    if (!try parser.expectPeek(allocator, .left_brace)) return null;
    const fields = try parseStructFields(parser, allocator) orelse return null;
    if (!try parser.expectPeek(allocator, .right_brace)) return null;

    return .{
        .span = .mergeFromSpans(struct_tok.span, parser.cur_tok.span),
        .kind = .{
            .struct_decl = .{
                .name = .{ .value = struct_name.lexeme },
                .fields = fields,
            },
        },
    };
}

fn parseStructFields(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?[]ast.StructDeclarationStatement.StructField {
    var fields: std.ArrayList(ast.StructDeclarationStatement.StructField) = .empty;
    errdefer fields.deinit(allocator);

    while (!parser.peekTokenIs(.right_brace)) {
        if (!try parser.expectPeek(allocator, .identifier)) return null;
        const field_name = parser.cur_tok;

        if (!try parser.expectPeek(allocator, .box_colon)) return null;
        parser.nextToken();

        const field_type = try pt.parseTypeExpression(parser, allocator) orelse return null;

        try fields.append(allocator, .{
            .name = .{ .value = field_name.lexeme },
            .type_expr = field_type,
        });

        if (parser.peekTokenIs(.right_brace)) break;
        if (!try parser.expectPeek(allocator, .comma)) return null;
        if (parser.peekTokenIs(.right_brace)) break;
    }

    return try fields.toOwnedSlice(allocator);
}
