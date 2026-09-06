const std = @import("std");
const BasicBlock = @import("basic_block.zig").BasicBlock;
const SemaType = @import("../sema/type_table.zig").SemaType;

pub const Param = struct { name: []const u8, sema_type: SemaType };

pub const Function = struct {
    name: []const u8,
    params: []const Param,
    return_type: SemaType,
    blocks: std.ArrayList(BasicBlock),
    next_value_id: u32 = 0,
    next_block_id: u32 = 0,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, params: []const Param, return_type: SemaType) Function {
        return .{ .name = name, .params = params, .return_type = return_type, .blocks = std.ArrayList(BasicBlock).init(allocator) };
    }
};
