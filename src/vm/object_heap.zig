const std = @import("std");
const Object = @import("object.zig").Object;
const IglotValue = @import("values.zig").IglotValue;

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
        const bytes = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(bytes);

        const obj = try self.allocator.create(Object);
        errdefer self.allocator.destroy(obj);

        obj.* = .{ .string = .{ .bytes = bytes } };
        return self.appendObject(obj);
    }

    pub fn createArray(self: *Self, elems: []IglotValue) !usize {
        const e = try self.allocator.dupe(IglotValue, elems);
        errdefer self.allocator.free(e);

        const obj = try self.allocator.create(Object);
        errdefer self.allocator.destroy(obj);

        obj.* = .{ .array = .{
            .len = elems.len,
            .elements = e,
        } };

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
            switch (obj.*) {
                .string => |s| self.allocator.free(s.bytes),
                .array => |a| self.allocator.free(a.elements),
            }
            self.allocator.destroy(obj);
        }
        self.objects.deinit(self.allocator);
    }
};
