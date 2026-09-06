const std = @import("std");
const Function = @import("function.zig").Function;

pub const Module = struct {
    functions: std.ArrayList(Function),

    pub fn init() Module {
        return .{
            .functions = .empty,
        };
    }

    pub fn deinit(self: *Module, allocator: std.mem.Allocator) void {
        self.functions.deinit(allocator);
    }

    pub fn currentFunction(self: *Module) *Function {
        const idx = self.functions.items.len - 1;
        return &self.functions.items[idx];
    }
};
