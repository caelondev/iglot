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

const std = @import("std");
const a = @import("../frontend/parser/ast.zig");
const typed_ast_mod = @import("../frontend/sema/typed_ast.zig");

const Context = @import("cli.zig").Context;
const InkDye = @import("inkdye");

const IglotLexer = @import("../frontend/lexer/lexer.zig").IglotLexer;
const IglotParser = @import("../frontend/parser/parser.zig").IglotParser;
const IglotModuleDriver = @import("../driver/driver.zig").IglotModuleDriver;
const IglotSemanticAnalyzer = @import("../frontend/sema/sema.zig").IglotSemanticAnalyzer;
const IglotIR = @import("../middle_end/ir/ir.zig").IglotIR;
const IglotCodegen = @import("../bytecode/codegen.zig").IglotCodegen;
const IglotVM = @import("../vm/vm.zig").IglotVM;

const VMContext = @import("../vm/builtins.zig").Context;

const dumpAny = @import("../debug/dump_any.zig").dumpAny;
const dumpBytecode = @import("../bytecode/disasm.zig").dumpBytecode;
const renderDiagnostics = @import("../diagnostics/render_diagnostics.zig").renderDiagnostics;
const pathExists = @import("helpers/path_exists.zig").pathExists;
const printModule = @import("../middle_end/ir/printer.zig").printModule;

/// Compiles and interprets an Iglot program.
pub fn run(ctx: *Context) !void {
    const allocator = ctx.arena.*.allocator();

    var dye = InkDye.initRuntime(.{
        .environ_map = ctx.environ_map,
        .allocator = allocator,
    });
    defer dye.deinit();

    var stderr = std.Io.File.stderr().writer(ctx.io, &.{});
    const ewriter = &stderr.interface;

    const path = ctx.argsIter.next() orelse {
        try ewriter.print("{s}: usage: iglot run <filepath>\n", .{
            try dye.red().bold().fmt("error", .{}),
        });
        return;
    };

    if (!try pathExists(ctx.io, path)) {
        try ewriter.print("{s}: path does not exist\n", .{
            try dye.red().bold().fmt("error", .{}),
        });
        return;
    }

    var stdout = std.Io.File.stdout().writer(ctx.io, &.{});
    const writer = &stdout.interface;

    var driver: IglotModuleDriver = .init();
    const modules = try driver.loadProgram(
        allocator,
        ctx.io,
        writer,
        ewriter,
        &dye,
        path,
    ) orelse return;

    var sema: IglotSemanticAnalyzer = .init();
    var typed_programs: std.ArrayList(typed_ast_mod.TypedProgram) = .empty;

    for (modules) |mod| {
        const typed = try sema.analyzeModule(allocator, mod.*);
        try typed_programs.append(allocator, typed);

        // diagnostics belong to the module just analyzed, so render them
        // against that module's own source, then clear for the next one
        if (sema.diagnostics.items.len != 0) {
            try renderSemaDiagnostics(writer, allocator, &dye, mod.source, &sema);
            sema.diagnostics.clearRetainingCapacity();
        }

        // stop at the first broken module. its dependents would only
        // produce cascading errors
        if (sema.errors > 0) return;
    }
    sema.deinit(allocator);

    // until IR is module-aware, feed it the entry module only (always last)
    const typed_ast = typed_programs.items[typed_programs.items.len - 1];

    // std.debug.print("typed ast:\n", .{});
    // try dumpAny(writer, typed_ast, 0);

    // IR
    var ir: IglotIR = .init();

    const ir_module = try ir.buildProgram(allocator, typed_ast) orelse return;
    ir.deinit(allocator);

    // try printModule(writer, ir_module.*);

    // Codegen
    var codegen: IglotCodegen = .init();
    const module = try codegen.generate(allocator, ir_module);

    // try dumpBytecode(writer, module);

    // stdin. buffer is just the read chunk size, prompt() streams
    // into a growing allocator so line length isn't capped by it
    var stdin_buf: [4096]u8 = undefined;
    var stdin = std.Io.File.stdin().reader(ctx.io, &stdin_buf);

    var iglot_vm: IglotVM = .init(module, .{
        .out = writer,
        .io = ctx.io,
        .in = &stdin.interface,
        .gpa = ctx.allocator,
    });
    defer iglot_vm.deinit(allocator);

    _ = try iglot_vm.run(allocator, module.entry);
}

fn renderSemaDiagnostics(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    dye: *InkDye.RuntimeChameleon,
    source: []const u8,
    sema: *const IglotSemanticAnalyzer,
) !void {
    for (sema.diagnostics.items) |diagnostic| {
        try renderDiagnostics(
            writer,
            allocator,
            dye,
            source,
            diagnostic,
        );
        try writer.writeByte('\n');
    }

    if (sema.errors == 0) return;
    try writer.writeAll(try dye.cyan().fmt("--> ", .{}));
    try writer.print("found {s}\n", .{
        try dye.red().fmt("{d} error(s)", .{
            sema.errors,
        }),
    });
}

fn renderDriverDiagnostics(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    dye: *InkDye.RuntimeChameleon,
    source: []const u8,
    driver: *const IglotModuleDriver,
) !void {
    for (driver.diagnostics.items) |diagnostic| {
        try renderDiagnostics(
            writer,
            allocator,
            dye,
            source,
            diagnostic,
        );
        try writer.writeByte('\n');
    }

    if (driver.errors == 0) return;
    try writer.writeAll(try dye.cyan().fmt("--> ", .{}));
    try writer.print("found {s}\n", .{
        try dye.red().fmt("{d} error(s)", .{
            driver.errors,
        }),
    });
}
