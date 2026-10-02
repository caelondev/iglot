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
//! Version command for iglot.
//!
//! Prints the current iglot version along with the build date.

const std = @import("std");
const iglot = @import("iglot_information");
const build_time = @import("build_time");
const Context = @import("cli.zig").Context;

/// Prints the iglot version and build date (or `dev` for dev builds).
pub fn version(ctx: *Context) !void {
    var writer = std.Io.File.stdout().writerStreaming(ctx.io, &.{});
    const out = &writer.interface;

    if (build_time.timestamp == 0) {
        try out.print("iglot {s} (dev)\n", .{iglot.version});
        return;
    }

    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(build_time.timestamp) };
    const year_day = epoch_seconds.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    try out.print("iglot {s} ({d}-{d:0>2}-{d:0>2})\n", .{
        iglot.version,
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
    });
}
