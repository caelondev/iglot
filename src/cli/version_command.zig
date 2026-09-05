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
//! Version command for cisco.
//!
//! Prints the current cisco version along with the build date.

const std = @import("std");
const cisco = @import("cisco_information");
const Context = @import("cli.zig").Context;

/// Prints the cisco version and build date.
pub fn version(ctx: *Context) !void {
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
