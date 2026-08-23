//! Copyright (C) 2026  caelondev
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU Affero General Public License as published
//! by the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU Affero General Public License for more details.
//!
//! You should have received a copy of the GNU Affero General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.
//!
//! Run command for cisco.
//!
//! Compiles and interprets a Cisco program.
//!
//! The run command is responsible for driving the language execution pipeline,
//! from parsing the source into an intermediate representation through
//! compilation and interpretation.

const std = @import("std");
const Context = @import("cli.zig").Context;
const CiscoLexer = @import("../lexer/cisco_lexer.zig").CiscoLexer;

/// Compiles and interprets a Cisco program.
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
