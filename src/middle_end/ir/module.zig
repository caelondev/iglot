const std = @import("std");
const Function = @import("function.zig").Function;
const inst = @import("instruction.zig");
const SemaType = @import("../../frontend/sema/type_table.zig").SemaType;

pub const Module = struct {
    functions: std.ArrayList(Function),
    globals: std.ArrayList(GlobalVariable),

    pub const GlobalVariable = struct {
        name: []const u8,
        sema_type: SemaType,
        initializer: inst.ConstantValue,
    };

    pub fn init() Module {
        return .{
            .functions = .empty,
            .globals = .empty,
        };
    }

    pub fn deinit(self: *Module, allocator: std.mem.Allocator) void {
        self.functions.deinit(allocator);
    }

    pub fn currentFunction(self: *Module) *Function {
        const idx = self.functions.items.len - 1;
        return &self.functions.items[idx];
    }

    pub fn addGlobal(self: *Module, allocator: std.mem.Allocator, global: GlobalVariable) !inst.GlobalRef {
        const id: u32 = @intCast(self.globals.items.len);
        try self.globals.append(allocator, global);
        return .{ .id = id };
    }

    pub fn newFunction(self: *Module) inst.FunctionRef {
        return inst.FunctionRef{
            .id = @intCast(self.functions.items.len),
        };
    }
};
