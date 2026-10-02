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
//! Command-line interface for iglot.
//!
//! Parses process arguments, dispatches them to the corresponding subcommand
//! handler, and provides each command with a shared execution context.
//!
//! Commands are registered in `commands` and selected by their command name.
//! When no command is provided, the CLI prints usage information. Unknown
//! commands are reported as errors.
//!
//! `Context` provides command handlers with the process arguments, remaining
//! argument iterator, general-purpose allocator, arena allocator, and
//! `std.Io` instance used for input and output.

const std = @import("std");
const InkDye = @import("inkdye");

/// Shared execution context provided to command handlers.
pub const Context = struct {
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    args: []const []const u8,
    environ_map: *std.process.Environ.Map,
    argsIter: std.process.Args.Iterator,
    io: std.Io,
};

const Command = fn (*Context) anyerror!void;

const commands: std.StaticStringMap(*const Command) = .initComptime(.{
    .{ "help", &@import("help_command.zig").help },
    .{ "version", &@import("version_command.zig").version },
    .{ "run", &@import("run_command.zig").run },
});

/// Entry point for the iglot command-line interface.
pub const IglotCLI = struct {
    args: []const []const u8,
    argsIter: std.process.Args.Iterator,

    const Self = @This();

    pub fn init(args: []const []const u8, argsIter: std.process.Args.Iterator) Self {
        return .{
            .args = args,
            .argsIter = argsIter,
        };
    }

    pub fn run(
        self: *Self,
        arena: *std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,
        io: std.Io,
        environ_map: *std.process.Environ.Map,
    ) !void {
        _ = self.argsIter.next(); // skip bin path

        var dye = InkDye.initRuntime(.{
            .environ_map = environ_map,
            .allocator = allocator,
        });
        defer dye.deinit();
        var stdout_writer = std.Io.File.stdout().writer(io, &.{});
        const writer = &stdout_writer.interface;

        const name = self.argsIter.next() orelse {
            try writer.print("usage: iglot [command] (options)\ntry: iglot help\n", .{});
            return;
        };

        const cmd = commands.get(name) orelse {
            const e = try dye.red().bold().fmt("error", .{});
            var stderr = std.Io.File.stderr().writer(io, &.{});
            const ewriter = &stderr.interface;
            try ewriter.print("{s}: usage: command not found\n", .{e});
            return;
        };

        var ctx: Context = .{
            .argsIter = self.argsIter,
            .args = self.args,
            .allocator = allocator,
            .arena = arena,
            .io = io,
            .environ_map = environ_map,
        };

        try cmd(&ctx);
    }
};
