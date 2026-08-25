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
const p = @import("../parser/parser.zig");
const dumpProgramAst = @import("../parser/debug/dump_program_ast.zig").dumpProgramAst;

/// Compiles and interprets a Cisco program.
pub fn run(ctx: Context) !void {
    const src =
        \\ 170141183460469231731687303715884105727
        \\ 67 69.0000 68.6278
        \\ "hello world"
        \\ apple orange
    ;

    const allocator = ctx.arena.*.allocator();

    var lexer = CiscoLexer.init(src);
    var parser = try p.CiscoParser.init(allocator, &lexer);
    var ast = try parser.parseProgram(allocator);
    const dump = try dumpProgramAst(allocator, &ast);
    std.debug.print("{s}", .{dump});
}
