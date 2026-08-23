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
const cisco = @import("cisco_information");
const build_time = @import("build_time");

const Context = struct {
    arena: *std.heap.ArenaAllocator,
    args: []const []const u8,
    argsIter: std.process.Args.Iterator,
    io: std.Io,
};

const Command = fn (Context) anyerror!void;

const commands: std.StaticStringMap(*const Command) = .initComptime(.{
    .{ "help", &help },
    .{ "version", &version },
});

pub const CiscoCLI = struct {
    arena: *std.heap.ArenaAllocator,
    args: []const []const u8,
    argsIter: std.process.Args.Iterator,

    const Self = @This();
    pub fn init(arena: *std.heap.ArenaAllocator, args: []const []const u8, argsIter: std.process.Args.Iterator) Self {
        return Self{
            .arena = arena,
            .argsIter = argsIter,
            .args = args,
        };
    }

    pub fn run(self: *Self, io: std.Io) !void {
        _ = self.argsIter.next(); // skip bin name
        var stdout_writer = std.Io.File.stdout().writer(io, &.{});
        const writer = &stdout_writer.interface;

        if (self.argsIter.next()) |a| {
            const c = commands.get(a);
            if (c) |cmd| {
                try cmd(.{
                    .argsIter = self.argsIter,
                    .args = self.args,
                    .arena = self.arena,
                    .io = io,
                });
            } else {
                try writer.print("error: command not found", .{});
            }
        } else {
            try writer.print("usage: cisco [command] (options)\ntry: cisco help", .{});
        }
    }
};

// ------------------------------
// ---------- COMMANDS ----------
// ------------------------------

fn help(ctx: Context) !void {
    const options = [_][2][]const u8{
        .{ "help", "Show this help message" },
        .{ "version", "Show version information" },
    };

    comptime var width = 0;
    comptime {
        for (options) |option| {
            width = @max(width, option[0].len);
        }
    }

    var writer = std.Io.File.stdout().writerStreaming(ctx.io, &.{});
    const out = &writer.interface;

    try out.writeAll("usage: cisco [command] [options]\n\n");
    try out.writeAll("options:\n");

    inline for (options) |option| {
        const name = option[0];
        const description = option[1];
        const padding = width - name.len;

        try out.print("  {s}", .{name});
        try out.splatByteAll(' ', padding + 4);
        try out.print("{s}\n", .{description});
    }
}

fn version(ctx: Context) !void {
    var writer = std.Io.File.stdout().writerStreaming(ctx.io, &.{});
    const out = &writer.interface;

    const now = std.Io.Clock.real.now(ctx.io);
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(now.toSeconds()) };
    const year_day = epoch_seconds.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    try out.print("cisco {s} ({d}-{d:0>2}-{d:0>2})\n", .{
        cisco.version,
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
    });
}
