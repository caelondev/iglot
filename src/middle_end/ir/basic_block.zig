const std = @import("std");
const Instruction = @import("instruction.zig").Instruction;
const BlockRef = @import("instruction.zig").BlockRef;

pub const BasicBlock = struct {
    id: BlockRef,
    name: []const u8,
    instructions: std.ArrayList(Instruction),

    const Self = @This();
    pub fn init(id: BlockRef, name: []const u8) Self {
        return .{
            .id = id,
            .name = name,
            .instructions = .empty,
        };
    }

    pub fn append(self: *Self, allocator: std.mem.Allocator, instr: Instruction) !void {
        try self.instructions.append(allocator, instr);
    }

    pub fn isTerminated(self: *Self) bool {
        if (self.instructions.items.len == 0) return false;
        const last = self.instructions.items[self.instructions.items.len - 1];
        return switch (last.op) {
            .ret, .ret_void, .cond_br, .br => true,
            else => false,
        };
    }
};
