const std = @import("std");
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const tt = @import("../../frontend/sema/type_table.zig");

pub const Params = struct {
    name: []const u8,
    index: u32,
    sema_type: tt.SemaType,
};

pub const Function = struct {
    function_name: []const u8,
    function_ref: inst.FunctionRef,
    params: std.ArrayList(Params),
    ret_type: tt.SemaType,
    blocks: std.ArrayList(*BasicBlock),
    next_block_id: u32,
    next_vreg_id: u32,

    const Self = @This();
    pub fn init(ref: inst.FunctionRef, name: []const u8, ret_type: tt.SemaType) Self {
        return .{
            .function_name = name,
            .function_ref = ref,
            .params = .empty,
            .ret_type = ret_type,
            .blocks = .empty,
            .next_block_id = 0,
            .next_vreg_id = 0,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.blocks.deinit(allocator);
    }

    pub fn newBlock(self: *Self, allocator: std.mem.Allocator, name: []const u8) !*BasicBlock {
        const b = try allocator.create(BasicBlock);
        b.* = .init(name, .{ .id = self.next_block_id });
        self.next_block_id += 1;
        try self.blocks.append(allocator, b);

        return b;
    }

    pub fn newVReg(self: *Self) inst.VReg {
        const vreg: inst.VReg = .{ .id = self.next_vreg_id };
        self.next_vreg_id += 1;
        return vreg;
    }

    pub fn getBlock(self: *Self, ref: inst.BlockRef) *BasicBlock {
        return self.blocks.items[ref.id];
    }

    pub fn appendParam(self: *Self, allocator: std.mem.Allocator, param: Params) !void {
        try self.params.append(allocator, param);
    }
};
