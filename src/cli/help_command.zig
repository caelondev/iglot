const std = @import("std");
const Context = @import("cli.zig").Context;

pub fn help(ctx: Context) !void {
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
