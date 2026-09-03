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
const InkDye = @import("inkdye");
const p = @import("../parser/parser.zig");
const dumpProgramAst = @import("../parser/debug/dump_program_ast.zig").dumpProgramAst;
const renderDiagnostics = @import("../diagnostics/render_diagnostics.zig").renderDiagnostics;
const CiscoSemanticAnalyzer = @import("../sema/sema.zig").CiscoSemanticAnalyzer;

/// Compiles and interprets a Cisco program.
pub fn run(ctx: Context) !void {
    const src =
        \\ a :: int = 5;
        \\ a = 10;
    ;

    const allocator = ctx.arena.*.allocator();

    var lexer = CiscoLexer.init(src);
    var parser = try p.CiscoParser.init(allocator, &lexer);
    var ast = try parser.parseProgram(allocator);

    var dye = InkDye.initRuntime(.{
        .environ_map = ctx.environ_map,
        .allocator = allocator,
    });
    defer dye.deinit();
    var stdout_writer = std.Io.File.stdout().writer(ctx.io, &.{});
    const writer = &stdout_writer.interface;
    for (parser.diagnostics.items, 0..) |d, i| {
        try renderDiagnostics(writer, allocator, &dye, src, d);
        if (i != parser.diagnostics.items.len - 1) {
            try writer.writeByte('\n');
        }
    }

    if (parser.diagnostics.items.len == 0) {
        const dump = try dumpProgramAst(allocator, &dye, &ast);
        std.debug.print("{s}", .{dump});
    } else return;

    var sema: CiscoSemanticAnalyzer = .init();
    _ = try sema.analyze(allocator, ast);

    if (sema.diagnostics.items.len != 0) {
        try writer.writeByte('\n');
        for (sema.diagnostics.items, 0..) |d, i| {
            try renderDiagnostics(writer, allocator, &dye, src, d);
            if (i != sema.diagnostics.items.len - 1) {
                try writer.writeByte('\n');
            }
        }
    }
}
