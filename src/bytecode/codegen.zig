const std = @import("std");
const bc = @import("bytecode.zig");
const Module = @import("module.zig").Module;
const IrModule = @import("../middle_end/ir/module.zig").Module;

pub const IglotCodegen = struct {
    module: Module,

    block_start: std.ArrayList(u32),
    reg_count: u16,

    pub fn init() IglotCodegen {
        return .{
            .module = undefined,
            .block_start = .empty,
            .reg_count = 0,
        };
    }

    pub fn deinit(self: *IglotCodegen, allocator: std.mem.Allocator) void {
        self.module.deinit();
        self.block_start.deinit(allocator);
    }

    pub fn generate(self: *IglotCodegen, ir_module: *const IrModule) !Module {
        _ = .{ self, ir_module };
        @panic("todo");
    }
};
