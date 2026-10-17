const std = @import("std");
const Object = @import("object.zig").Object;

pub const ObjectHeap = struct {
    allocator: std.mem.Allocator,
    objects: std.ArrayList(*Object),

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .objects = .empty,
        };
    }

    pub fn createString(self: *Self, value: []const u8) !usize {
        const obj = try self.allocator.create(Object);
        obj.* = .{ .string = .{ .bytes = value } };
        return self.appendObject(obj);
    }

    fn appendObject(self: *Self, object: *Object) !usize {
        const ref = self.objects.items.len;
        try self.objects.append(self.allocator, object);
        return ref;
    }

    pub fn resolveRef(self: *Self, ref: usize) *Object {
        return self.objects.items[ref];
    }

    pub fn deinit(self: *Self) void {
        for (self.objects.items) |obj| {
            self.allocator.destroy(obj);
        }
        self.objects.deinit(self.allocator);
    }
};
