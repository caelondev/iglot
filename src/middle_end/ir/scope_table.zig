const std = @import("std");
const inst = @import("instruction.zig");

pub const ScopeTable = struct {
    bindings: std.StringHashMapUnmanaged(inst.VReg),

    const Self = @This();

    pub fn init() Self {
        return .{
            .bindings = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.bindings.deinit(allocator);
    }

    pub fn declareMapping(self: *Self, allocator: std.mem.Allocator, name: []const u8, vreg: inst.VReg) !void {
        try self.bindings.put(allocator, name, vreg);
    }

    pub fn resolve(self: *const Self, name: []const u8) ?inst.VReg {
        return self.bindings.get(name);
    }
};

pub const ScopeStack = struct {
    scopes: std.ArrayListUnmanaged(ScopeTable),

    const Self = @This();

    pub fn init() Self {
        return .{
            .scopes = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.scopes.items) |*scope| scope.deinit(allocator);
        self.scopes.deinit(allocator);
    }

    pub fn push(self: *Self, allocator: std.mem.Allocator) !void {
        try self.scopes.append(allocator, ScopeTable.init());
    }

    pub fn pop(self: *Self, allocator: std.mem.Allocator) void {
        var scope = self.scopes.pop().?;
        scope.deinit(allocator);
    }

    pub fn declare(self: *Self, allocator: std.mem.Allocator, name: []const u8, vreg: inst.VReg) !void {
        try self.scopes.items[self.scopes.items.len - 1].declareMapping(allocator, name, vreg);
    }

    pub fn resolve(self: *const Self, name: []const u8) ?inst.VReg {
        var i = self.scopes.items.len;
        while (i > 0) {
            i -= 1;
            if (self.scopes.items[i].resolve(name)) |reg| return reg;
        }
        return null;
    }
};
