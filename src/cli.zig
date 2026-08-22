const std = @import("std");

const Context = struct {
    arena: *std.heap.ArenaAllocator,
    args: *[]const []const u8,
    argsIter: *std.process.Args.Iterator,
    io: std.Io,
};

const Command = fn (Context) void;
const commands: std.StaticStringMap(Command) = .initComptime(.{});

pub const CiscoCLI = struct {
    arena: *std.heap.ArenaAllocator,
    args: *[]const []const u8,
    argsIter: *std.process.Args.Iterator,

    const Self = @This();
    pub fn init(arena: *std.heap.ArenaAllocator, args: *[]const []const u8, argsIter: *std.process.Args.Iterator) Self {
        return Self{
            .arena = arena,
            .argsIter = argsIter,
            .args = args,
        };
    }

    pub fn run(self: *Self, io: std.Io) void {
        _ = self.argsIter.next(); // skip bin name

        if (self.argsIter.next()) |a| {
            const c = commands.get(a);
            if (c) |cmd| cmd(.{
                .argsIter = self.argsIter,
                .args = self.args,
                .arena = self.arena,
                .io = io,
            });
        } else help();
    }
};

fn help(ctx: Context) !void {
    const options = [_][2][]const u8{
        .{ "--help, -h", "Show this help message" },
        .{ "--version, -v", "Show version information" },
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
