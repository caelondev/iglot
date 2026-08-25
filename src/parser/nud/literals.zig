const std = @import("std");

const CiscoParser = @import("../parser.zig").CiscoParser;
const ast = @import("../ast.zig");

pub fn parseInteger(
    parser: *CiscoParser,
    allocator: std.mem.Allocator,
) !?ast.Expression {
    const lit_raw = parser.advance();

    const integer = std.fmt.parseInt(i128, lit_raw.lexeme, 10) catch |err| {
        switch (err) {
            error.Overflow => {
                try parser.reportError(
                    allocator,
                    .{
                        .span = lit_raw.span,
                        .kind = .IntegerOverflow,
                    },
                );

                return null;
            },

            error.InvalidCharacter => unreachable,
        }
    };

    const integer_expr: ast.IntegerExpression = .{
        .value = integer,
    };

    return .{
        .integer = integer_expr,
    };
}

pub fn parseFloat(parser: *CiscoParser, _: std.mem.Allocator) !?ast.Expression {
    const lit_raw = parser.advance();

    const float = std.fmt.parseFloat(f64, lit_raw.lexeme) catch |err| {
        switch (err) {
            error.InvalidCharacter => unreachable,
        }
    };

    const float_expr: ast.FloatExpression = .{
        .value = float,
    };

    return .{
        .float = float_expr,
    };
}

pub fn parseIdentifier(parser: *CiscoParser, _: std.mem.Allocator) !?ast.Expression {
    const lit_raw = parser.advance();
    const ident_expr: ast.IdentifierExpression = .{ .value = lit_raw.lexeme };
    return .{ .identifier = ident_expr };
}

pub fn parseString(parser: *CiscoParser, _: std.mem.Allocator) !?ast.Expression {
    const lit_raw = parser.advance();
    const str_expr: ast.StringExpression = .{ .value = lit_raw.lexeme };
    return .{ .string = str_expr };
}
