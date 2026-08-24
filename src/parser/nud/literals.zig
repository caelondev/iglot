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
