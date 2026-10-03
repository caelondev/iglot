const std = @import("std");
const bc = @import("bytecode.zig");
const Module = @import("module.zig").Module;

pub fn dump(m: *const Module, writer: anytype) !void {
    _ = .{ m, writer };
    @panic("todo");
}
