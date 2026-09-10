const std = @import("std");
const BasicBlock = @import("basic_block.zig").BasicBlock;
const SemaType = @import("../sema/type_table.zig").SemaType;
const BlockRef = @import("instruction.zig").BlockRef;
const ValueRef = @import("instruction.zig").ValueRef;
const FunctionRef = @import("instruction.zig").FunctionRef;

pub const Function = struct {
    id: FunctionRef,
    name: []const u8,
    params: []const Param,
    return_type: SemaType,
    blocks: std.ArrayList(*BasicBlock),
    next_value_id: u32 = 0,
    next_block_id: u32 = 0,

    pub const Param = struct { name: []const u8, sema_type: SemaType };

    pub fn init(id: FunctionRef, name: []const u8, params: []const Param, return_type: SemaType) Function {
        return .{
            .id = id,
            .name = name,
            .params = params,
            .return_type = return_type,
            .blocks = .empty,
        };
    }

    pub fn newBlock(self: *Function, allocator: std.mem.Allocator, name: []const u8) !BlockRef {
        const id = self.next_block_id;
        self.next_block_id += 1;

        const block = try allocator.create(BasicBlock);
        block.* = BasicBlock.init(.{ .id = id }, name);
        try self.blocks.append(allocator, block);

        return .{ .id = id };
    }

    pub fn newValue(self: *Function) ValueRef {
        const id = self.next_value_id;
        self.next_value_id += 1;
        return .{ .id = id };
    }

    pub fn getBlock(self: *Function, idx: usize) *BasicBlock {
        return self.blocks.items[idx];
    }
};
