const std = @import("std");

pub const Object = union(enum) {
    string: String,

    pub const String = struct {
        bytes: []const u8,
    };
};
