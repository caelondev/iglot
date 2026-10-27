const std = @import("std");
const IglotValue = @import("values.zig").IglotValue;

pub const Object = union(enum) {
    string: String,
    array: Array,

    pub const String = struct {
        bytes: []const u8,
    };

    pub const Array = struct {
        elements: []IglotValue,
        len: usize,
    };
};
