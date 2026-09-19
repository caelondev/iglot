const std = @import("std");
const inst = @import("instruction.zig");

pub const BasicBlock = struct {
    name: []const u8,
    id: inst.BlockRef,
    instructions: std.ArrayList(inst.Instruction),

    const Self = @This();
    pub fn init(name: []const u8, ref: inst.BlockRef) Self {
        return .{
            .name = name,
            .id = ref,
            .instructions = .empty,
        };
    }
};
