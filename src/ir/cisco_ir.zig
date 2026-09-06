const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");

pub const CiscoIR = struct {
    module: Module,
    current_fn: *Function = undefined,
    current_block: *BasicBlock = undefined,
    locals: std.StringHashMap(inst.ValueRef),

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .locals = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.module.deinit(allocator);
        self.locals.deinit();
    }
};
