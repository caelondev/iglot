const std = @import("std");
const Function = @import("function.zig").Function;
const inst = @import("instruction.zig");

pub const Module = struct {
    functions: std.StringHashMapUnmanaged(*Function),
    next_function_id: u32,

    pub fn init() Module {
        return .{
            .functions = .empty,
            .next_function_id = 0,
        };
    }

    pub fn deinit(self: *Module, allocator: std.mem.Allocator) void {
        var iter = self.functions.valueIterator();

        while (iter.next()) |function| {
            allocator.destroy(function.*);
        }

        self.functions.deinit(allocator);
    }

    pub fn getFunction(
        self: *Module,
        name: []const u8,
    ) ?*Function {
        return self.functions.get(name);
    }

    pub fn createFunction(
        self: *Module,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !*Function {
        const ref: inst.FunctionRef = .{
            .id = self.next_function_id,
        };

        self.next_function_id += 1;

        const function = try allocator.create(Function);
        errdefer allocator.destroy(function);

        function.* = .init(name, ref);

        try self.functions.put(
            allocator,
            name,
            function,
        );

        return function;
    }
};
