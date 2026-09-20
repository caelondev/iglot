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

    pub fn isTerminated(self: *Self) bool {
        if (self.instructions.items.len == 0) return false;

        const last_inst = self.instructions.items[self.instructions.items.len - 1];
        return switch (last_inst.op) {
            .br, .cond_br, .ret, .ret_void => true,
            else => false,
        };
    }
};
