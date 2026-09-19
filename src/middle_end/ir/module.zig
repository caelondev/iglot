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
        for (self.functions.items) |*function| {
            function.deinit(allocator);
        }

        self.functions.deinit(allocator);
    }

    pub fn addFunction(
        self: *Module,
        allocator: std.mem.Allocator,
        function: Function,
    ) !void {
        try self.functions.append(allocator, function);
    }
};
