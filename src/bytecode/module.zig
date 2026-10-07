const std = @import("std");
const bc = @import("bytecode.zig");

pub const Function = struct {
    name: []const u8,
    code_start: u32 = 0,
    param_count: u16,
    reg_count: u16 = 0,
    code: std.ArrayList(bc.Instruction),

    pub fn init(name: []const u8, param_count: u16) Function {
        return .{
            .name = name,
            .param_count = param_count,
            .reg_count = 0,
            .code = .empty,
        };
    }

    pub fn deinit(self: *Function, allocator: std.mem.Allocator) void {
        self.code.deinit(allocator);
    }
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
        return intern(i64, &self.ints, alloc, v);
    }

    pub fn addWideInt(self: *ConstantPool, alloc: std.mem.Allocator, v: i128) !u32 {
        return intern(i128, &self.wideints, alloc, v);
    }
    pub fn addFloat(self: *ConstantPool, alloc: std.mem.Allocator, v: f32) !u32 {
        return intern(f32, &self.floats, alloc, v);
    }
    pub fn addDouble(self: *ConstantPool, alloc: std.mem.Allocator, v: f64) !u32 {
        return intern(f64, &self.doubles, alloc, v);
    }
    pub fn addString(self: *ConstantPool, alloc: std.mem.Allocator, s: []const u8) !u32 {
        for (self.strings.items, 0..) |interned, i| {
            if (std.mem.eql(u8, interned, s)) return @intCast(i);
        }

        const owned = try alloc.dupe(u8, s);
        errdefer alloc.free(owned);
        try self.strings.append(alloc, owned);
        return @intCast(self.strings.items.len - 1);
    }

    fn intern(T: type, list: *std.ArrayList(T), allocator: std.mem.Allocator, v: T) !u32 {
        for (list.items, 0..) |existing, i| {
            if (std.mem.eql(u8, std.mem.asBytes(&existing), std.mem.asBytes(&v))) {
                return @intCast(i);
            }
        }
        try list.append(allocator, v);
        return @intCast(list.items.len - 1);
    }
};

pub const Module = struct {
    functions: std.ArrayList(Function),
    constants: ConstantPool,
    global_count: u32,
    entry: ?u32,
    init_fn: ?u32,

    const Self = @This();
    pub fn init() Self {
        return .{
            .functions = .empty,
            .constants = .init(),
            .global_count = 0,
            .entry = null,
            .init_fn = null,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.functions.deinit(allocator);
        self.constants.deinit(allocator);
    }

    pub fn declareFunction(self: *Self, allocator: std.mem.Allocator, name: []const u8, param_count: u16) !u32 {
        try self.functions.append(allocator, .init(name, param_count));
        return @intCast(self.functions.items.len - 1);
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, func_ref: u32, inst: bc.Instruction) !u32 {
        const code = &self.functions.items[func_ref].code;
        try code.append(allocator, inst);
        return @intCast(code.items.len - 1);
    }
};
