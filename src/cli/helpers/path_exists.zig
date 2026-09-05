const std = @import("std");

pub fn pathExists(io: std.Io, path: []const u8) !bool {
    std.Io.Dir.cwd().access(io, path, .{}) catch |err|
        {
            if (err == error.FileNotFound) return false;
            return err;
        };
    return true;
}
