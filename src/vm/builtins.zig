const std = @import("std");
const bc = @import("../bytecode/bytecode.zig");
const IglotValue = @import("values.zig").IglotValue;

const BuiltinIglotFunctionError = std.Io.Writer.Error;

const Context = struct {
    out: *std.Io.Writer,
};

pub const BuiltinIglotFunction = fn (ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue;

pub const Builtin = struct {
    name: []const u8,
    arity: u8,
    func: BuiltinIglotFunction,
};

pub const table = [_]Builtin{
    .{ .name = "print", .arity = 1, .func = print },
    .{ .name = "println", .arity = 1, .func = println },
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
