const std = @import("std");

pub fn dumpAny(writer: *std.Io.Writer, value: anytype, indent: usize) anyerror!void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    switch (info) {
        .pointer => |p| {
            if (p.size == .one) {
                try dumpAny(writer, value.*, indent);
            } else if (p.size == .slice and p.child == u8) {
                try writer.print("\"{s}\"\n", .{value});
            } else if (p.size == .slice) {
                for (value) |item| try dumpAny(writer, item, indent);
            } else {
                try writer.print("{any}\n", .{value});
            }
        },
        .@"struct" => |s| {
            try writer.writeByte('\n');
            inline for (s.fields) |field| {
                if (comptime std.mem.eql(u8, field.name, "span")) continue;

                try writeIndent(writer, indent + 1);
                try writer.print("{s}: ", .{field.name});
                try dumpAny(writer, @field(value, field.name), indent + 1);
            }
        },
        .@"union" => |u| {
            if (u.tag_type != null) {
                try writer.print("{s} -> ", .{@tagName(value)});
                switch (value) {
                    inline else => |payload| try dumpAny(writer, payload, indent),
                }
            } else {
                try writer.print("{any}\n", .{value});
            }
        },
        .optional => {
            if (value) |payload| {
                try dumpAny(writer, payload, indent);
            } else {
                try writer.writeAll("null\n");
            }
        },
        .@"enum" => try writer.print("{s}\n", .{@tagName(value)}),
        .int, .float, .bool => try writer.print("{any}\n", .{value}),
        else => try writer.print("{any}\n", .{value}),
    }
}

fn writeIndent(writer: *std.Io.Writer, n: usize) !void {
    try writer.splatByteAll(' ', n * 2);
}
