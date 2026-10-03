const std = @import("std");
const bc = @import("bytecode.zig");

pub const Function = struct {
    name: []const u8,
    code_start: u32 = 0,
    param_count: u16,
    reg_count: u16 = 0,
};

pub const ConstantPool = struct {
    ints: std.ArrayListUnmanaged(i64),
    wideints: std.ArrayListUnmanaged(i128),
    floats: std.ArrayListUnmanaged(f32),
    doubles: std.ArrayListUnmanaged(f64),
    strings: std.ArrayListUnmanaged([]const u8),

    pub fn init() ConstantPool {
        return .{
            .ints = .empty,
            .wideints = .empty,
            .floats = .empty,
            .doubles = .empty,
            .strings = .empty,
        };
    }

    pub fn deinit(self: *ConstantPool, alloc: std.mem.Allocator) void {
        self.ints.deinit(alloc);
        self.wideints.deinit(alloc);
        self.floats.deinit(alloc);
        self.doubles.deinit(alloc);
        self.strings.deinit(alloc);
    }

    pub fn addInt(self: *ConstantPool, alloc: std.mem.Allocator, v: i64) !u32 {
        _ = .{ self, alloc, v };
        @panic("todo");
    }
    pub fn addWideInt(self: *ConstantPool, alloc: std.mem.Allocator, v: i128) !u32 {
        _ = .{ self, alloc, v };
        @panic("todo");
    }
    pub fn addFloat(self: *ConstantPool, alloc: std.mem.Allocator, v: f32) !u32 {
        _ = .{ self, alloc, v };
        @panic("todo");
    }
    pub fn addDouble(self: *ConstantPool, alloc: std.mem.Allocator, v: f64) !u32 {
        _ = .{ self, alloc, v };
        @panic("todo");
    }
    pub fn addString(self: *ConstantPool, alloc: std.mem.Allocator, s: []const u8) !u32 {
        _ = .{ self, alloc, s };
        @panic("todo");
    }
};

pub const Module = struct {
    code: std.ArrayList(bc.Instruction),
    functions: std.ArrayList(Function),
    constants: ConstantPool,
    global_count: u32,
    entry: ?u32,
    init_fn: ?u32,

    pub fn init() Module {
        return .{
            .code = .empty,
            .functions = .empty,
            .constants = .init(),
            .global_count = 0,
            .entry = null,
            .init_fn = null,
        };
    }

    pub fn deinit(self: *Module, allocator: std.mem.Allocator) void {
        self.code.deinit(allocator);
        self.functions.deinit(allocator);
        self.constants.deinit(allocator);
    }
};
