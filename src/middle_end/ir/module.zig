const std = @import("std");
const Function = @import("function.zig").Function;
const inst = @import("instruction.zig");
const tt = @import("../../frontend/sema/type_table.zig");

pub const Module = struct {
    functions: std.ArrayListUnmanaged(*Function),
    function_names: std.StringHashMapUnmanaged(u32),
    globals: std.ArrayList(inst.Global),
    next_function_id: u32,

    pub fn init() Module {
        return .{
            .functions = .empty,
            .globals = .empty,
            .function_names = .empty,
            .next_function_id = 0,
        };
    }

    pub fn deinit(self: *Module, allocator: std.mem.Allocator) void {
        for (self.functions.items) |function| {
            allocator.destroy(function);
        }

        self.functions.deinit(allocator);
        self.function_names.deinit(allocator);
        self.globals.deinit(allocator);
    }

    pub fn getFunction(self: *Module, ref: inst.FunctionRef) *Function {
        return self.functions.items[ref.id];
    }

    pub fn getFunctionByName(self: *Module, name: []const u8) ?*Function {
        const id = self.function_names.get(name) orelse return null;
        return self.functions.items[id];
    }

    pub fn createFunction(
        self: *Module,
        allocator: std.mem.Allocator,
        name: []const u8,
        ret_type: tt.SemaType,
    ) !*Function {
        const ref: inst.FunctionRef = .{ .id = self.next_function_id };
        self.next_function_id += 1;

        const function = try allocator.create(Function);
        errdefer allocator.destroy(function);
        function.* = .init(ref, name, ret_type);

        try self.functions.append(allocator, function);
        try self.function_names.put(allocator, name, ref.id);

        return function;
    }
};
