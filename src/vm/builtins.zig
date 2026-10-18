const std = @import("std");
const bc = @import("../bytecode/bytecode.zig");
const SemaType = @import("../frontend/sema/type_table.zig").SemaType;
const IglotValue = @import("values.zig").IglotValue;
const IglotVM = @import("vm.zig").IglotVM;
const Object = @import("object.zig").Object;
const ObjectHeap = @import("object_heap.zig").ObjectHeap;

const BuiltinIglotFunctionError = std.Io.Writer.Error;

pub const Context = struct {
    gpa: std.mem.Allocator,
    out: *std.Io.Writer,
};

pub const BuiltinIglotFunction = *const fn (vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue;

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

fn print(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    try writeValue(ctx.out, &vm.object_heap, args[0]);
    return unit;
}

fn println(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    try writeValue(ctx.out, &vm.object_heap, args[0]);
    try ctx.out.writeByte('\n');
    return unit;
}

fn writeHeapValue(out: *std.Io.Writer, obj: *Object) !void {
    switch (obj.*) {
        .string => |s| try out.writeAll(s.bytes),
    }
}

fn writeValue(out: *std.Io.Writer, obj_heap: *ObjectHeap, v: IglotValue) std.Io.Writer.Error!void {
    switch (v) {
        .int => |x| try out.print("{d}", .{x}),
        .wideint => |x| try out.print("{d}", .{x}),
        .float => |x| try writeFloat(out, x),
        .double => |x| try writeFloat(out, x),
        .bool => |x| try out.writeAll(if (x == 1) "true" else "false"),
        .func => |id| try out.print("<fn [{d}]>", .{id}),
        .builtin_ref => |ref| try out.print("<builtin fn [{d}]>", .{ref}),
        .heap_ref => |ref| {
            const val = obj_heap.resolveRef(ref);
            try writeHeapValue(out, val);
        },
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
