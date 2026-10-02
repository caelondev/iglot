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
//! Help command for iglot.
//!
//! Prints the available commands and their descriptions in a formatted
//! command-line help message.

const std = @import("std");
const Context = @import("cli.zig").Context;

/// Prints the iglot command-line help message.
pub fn help(ctx: *Context) !void {
    const options = [_][2][]const u8{
        .{ "help", "Show this help message" },
        .{ "run <filepath>", "Runs a Iglot program" },
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

    try out.writeAll("usage: iglot [command] [options]\n\n");
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
