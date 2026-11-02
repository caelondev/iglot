const std = @import("std");
const StructDesc = @import("../middle_end/ir/module.zig").StructDesc;
const IglotValue = @import("values.zig").IglotValue;

pub const Object = union(enum) {
    string: String,
    array: Array,
    struct_init: StructInit,

    pub const String = struct {
        bytes: []const u8,
    };

    pub const Array = struct {
        elements: []IglotValue,
        len: usize,
    };

    pub const StructInit = struct {
        desc: *const StructDesc,
        fields: []IglotValue,
    };
};
