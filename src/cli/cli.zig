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
//!
//! Command-line interface for cisco.
//!
//! Parses process arguments, dispatches to the matching subcommand handler
//! in `commands`, and falls back to `help` when no command is given or the
//! given command isn't recognized. Each command receives a `Context`
//! carrying the arena allocator, raw args, the remaining argument iterator,
//! and the `std.Io` instance used for output.

const std = @import("std");

pub const Context = struct {
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    args: []const []const u8,
    argsIter: std.process.Args.Iterator,
    io: std.Io,
};

const Command = fn (Context) anyerror!void;

const commands: std.StaticStringMap(*const Command) = .initComptime(.{
    .{ "help", &@import("help_command.zig").help },
    .{ "version", &@import("version_command.zig").version },
    .{ "run", &@import("run_command.zig").run },
});

pub const CiscoCLI = struct {
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
    ) !void {
        _ = self.argsIter.next(); // skip bin name

        var stdout_writer = std.Io.File.stdout().writer(io, &.{});
        const writer = &stdout_writer.interface;

        const name = self.argsIter.next() orelse {
            try writer.print("usage: cisco [command] (options)\ntry: cisco help\n", .{});
            return;
        };

        const cmd = commands.get(name) orelse {
            try writer.print("error: command not found", .{});
            return;
        };

        try cmd(.{
            .argsIter = self.argsIter,
            .args = self.args,
            .allocator = allocator,
            .arena = arena,
            .io = io,
        });
    }
};
