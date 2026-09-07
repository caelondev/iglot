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
//! Run command for faru.
//!
//! Compiles and interprets a Faru program.
//!
//! The run command is responsible for driving the language execution pipeline,
//! from parsing the source into an intermediate representation through
//! compilation and interpretation.

const std = @import("std");
const Context = @import("cli.zig").Context;
const FaruLexer = @import("../lexer/faru_lexer.zig").FaruLexer;
const InkDye = @import("inkdye");
const p = @import("../parser/parser.zig");
const dumpAny = @import("../debug/dump_any.zig").dumpAny;
const renderDiagnostics = @import("../diagnostics/render_diagnostics.zig").renderDiagnostics;
const pathExists = @import("helpers/path_exists.zig").pathExists;
const FaruSemanticAnalyzer = @import("../sema/sema.zig").FaruSemanticAnalyzer;
const FaruIR = @import("../ir/faru_ir.zig").FaruIR;
const printModule = @import("../ir/printer.zig").printModule;

/// Compiles and interprets a Faru program.
pub fn run(ctx: *Context) !void {
    const allocator = ctx.arena.*.allocator();

    var dye = InkDye.initRuntime(.{
        .environ_map = ctx.environ_map,
        .allocator = allocator,
    });
    defer dye.deinit();

    const e = try dye.red().bold().fmt("error", .{});
    var stderr = std.Io.File.stderr().writer(ctx.io, &.{});
    const ewriter = &stderr.interface;

    const path = ctx.argsIter.next() orelse {
        try ewriter.print("{s}: usage: faru run <filepath>\n", .{e});
        return;
    };

    if (!try pathExists(ctx.io, path)) {
        try ewriter.print("{s}: path does not exist\n", .{e});
        return;
    }

    const cwd = std.Io.Dir.cwd();
    const src = try cwd.readFileAlloc(ctx.io, path, allocator, .unlimited);

    var lexer = FaruLexer.init(src);
    var parser = try p.FaruParser.init(allocator, &lexer);
    const ast = try parser.parseProgram(allocator);

    var stdout_writer = std.Io.File.stdout().writer(ctx.io, &.{});
    const writer = &stdout_writer.interface;
    for (parser.diagnostics.items, 0..) |d, i| {
        try renderDiagnostics(writer, allocator, &dye, src, d);
        if (i != parser.diagnostics.items.len - 1) {
            try writer.writeByte('\n');
        }
    }

    if (parser.diagnostics.items.len == 0) {
        std.debug.print("parsed ast:", .{});
        try dumpAny(writer, ast, 0);
    } else return;

    var sema: FaruSemanticAnalyzer = .init();
    const t_ast = try sema.analyze(allocator, ast);
    if (sema.diagnostics.items.len != 0) {
        try writer.writeByte('\n');
        for (sema.diagnostics.items) |d| {
            try renderDiagnostics(writer, allocator, &dye, src, d);
            try writer.writeByte('\n');
        }

        try writer.writeAll(
            try dye.cyan().fmt("--> ", .{}),
        );
        try writer.print("found {s}\n", .{
            try dye.red().fmt("{d} error(s)", .{
                sema.diagnostics.items.len,
            }),
        });
    } else {
        std.debug.print("typed ast:", .{});
        try dumpAny(writer, t_ast, 0);

        var ir_builder: FaruIR = .init();
        defer ir_builder.deinit(allocator);

        try ir_builder.buildProgram(allocator, t_ast);

        try writer.writeByte('\n');
        std.debug.print("ir module:\n", .{});
        try printModule(writer, ir_builder.module);
    }
}
