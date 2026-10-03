const std = @import("std");
const bc = @import("bytecode.zig");
const Module = @import("module.zig").Module;

pub fn dumpBytecode(writer: *std.Io.Writer, module: *const Module) !void {
    _ = .{ module, writer };
    @panic("todo");
}
