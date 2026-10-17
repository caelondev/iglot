const std = @import("std");
const bc = @import("../bytecode/bytecode.zig");
const SemaType = @import("../frontend/sema/type_table.zig").SemaType;
const IglotValue = @import("values.zig").IglotValue;

const BuiltinIglotFunctionError = std.Io.Writer.Error;

pub const Context = struct {
    out: *std.Io.Writer,
};

pub const BuiltinIglotFunction = *const fn (ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue;

pub const Builtin = struct {
    name: []const u8,
    params: []const SemaType,
    ret_type: SemaType,
    func: BuiltinIglotFunction,

    /// the .function type sema puts in scope
    pub fn semaType(self: Builtin, allocator: std.mem.Allocator) !SemaType {
        const params = try allocator.alloc(*SemaType, self.params.len);
        for (self.params, params) |p, *slot| {
            slot.* = try allocator.create(SemaType);
            slot.*.* = p;
        }
        const ret = try allocator.create(SemaType);
        ret.* = self.ret_type;
        return .{ .function = .{ .parameters = params, .return_type = ret } };
    }
};

pub const table = [_]Builtin{
    .{ .name = "print", .params = &.{.any}, .ret_type = .void, .func = &print },
    .{ .name = "println", .params = &.{.any}, .ret_type = .void, .func = &println },
};

pub fn lookupBuiltin(name: []const u8) ?u16 {
    for (table, 0..) |v, i| {
        if (std.mem.eql(u8, v.name, name)) return @intCast(i);
    }

    return null;
}

/// what void builtins return. codegen passes no_reg as the ret reg so it's never read
const unit: IglotValue = .{ .int = 0 };

fn print(ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    try writeValue(ctx.out, args[0]);
    return unit;
}

fn println(ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    try writeValue(ctx.out, args[0]);
    try ctx.out.writeByte('\n');
    return unit;
}

fn writeValue(out: *std.Io.Writer, v: IglotValue) std.Io.Writer.Error!void {
    switch (v) {
        .int => |x| try out.print("{d}", .{x}),
        .wideint => |x| try out.print("{d}", .{x}),
        .float => |x| try writeFloat(out, x),
        .double => |x| try writeFloat(out, x),
        .bool => |x| try out.writeAll(if (x == 1) "true" else "false"),
        .func => |id| try out.print("<fn {d}>", .{id}),
    }
}

fn writeFloat(out: *std.Io.Writer, x: anytype) std.Io.Writer.Error!void {
    // {d} prints 3.0 as "3" which reads like an int, so patch whole floats
    if (std.math.isFinite(x) and @floor(x) == x and @abs(x) < 1e15) {
        try out.print("{d}.0", .{x});
    } else {
        try out.print("{d}", .{x});
    }
}
