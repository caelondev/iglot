const std = @import("std");
const Context = @import("cli.zig").Context;
const CiscoLexer = @import("../lexer/cisco_lexer.zig").CiscoLexer;

pub fn run(ctx: Context) !void {
    _ = ctx;

    const src =
        \\ ! = < = > = = =
        \\ != <= >= == !=
    ;

    var lexer = CiscoLexer.init(src);

    while (true) {
        var token = lexer.nextToken();
        token.debug();

        if (token.kind == .eof)
            break;
    }
}
