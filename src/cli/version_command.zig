const std = @import("std");
const cisco = @import("cisco_information");
const build_time = @import("build_time");
const Context = @import("cli.zig").Context;

pub fn version(ctx: Context) !void {
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
