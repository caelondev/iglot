/// TODO: parse_to_*: change return type from `?T` to `error T`
/// TODO: fetch: this builtin function is hardcoded to only do a GET request.
///       after implementing enums, we should add another parameter that allows us to
///       change request kind
///
const std = @import("std");
const bc = @import("../bytecode/bytecode.zig");
const singleton = @import("singleton.zig");
const SemaType = @import("../frontend/sema/type_table.zig").SemaType;
const IglotValue = @import("values.zig").IglotValue;
const IglotVM = @import("vm.zig").IglotVM;
const Object = @import("object.zig").Object;
const ObjectHeap = @import("object_heap.zig").ObjectHeap;
const StructDesc = @import("../middle_end/ir/module.zig").StructDesc;

pub const BuiltinIglotFunctionError =
    std.Io.Writer.Error || std.Io.Reader.Error || std.mem.Allocator.Error;

pub const Context = struct {
    gpa: std.mem.Allocator,
    out: *std.Io.Writer,
    io: std.Io,
    in: *std.Io.Reader,
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

var ANY_TYPE: SemaType = .any;
const UNBOUNDED_ARRAY_ANY: SemaType = .{
    .array = .{
        .element_type = &ANY_TYPE,
        .size = .unbounded,
    },
};

var FETCH_RESULT_STRUCT: SemaType.Struct = undefined;
var FETCH_RESULT_SEMA: SemaType = .{ .@"struct" = &FETCH_RESULT_STRUCT };

var INT_TYPE: SemaType = .int;
var WIDEINT_TYPE: SemaType = .wideint;
var FLOAT_TYPE: SemaType = .float;
var DOUBLE_TYPE: SemaType = .double;

pub const table = [_]Builtin{
    .{ .name = "print", .params = &.{UNBOUNDED_ARRAY_ANY}, .ret_type = .void, .func = &print },
    .{ .name = "println", .params = &.{UNBOUNDED_ARRAY_ANY}, .ret_type = .void, .func = &println },
    .{ .name = "prompt", .params = &.{.string}, .ret_type = .string, .func = &prompt },
    .{ .name = "parse_to_int", .params = &.{.string}, .ret_type = .{ .nullable = &INT_TYPE }, .func = &parse_to_int },
    .{ .name = "parse_to_wideint", .params = &.{.string}, .ret_type = .{ .nullable = &WIDEINT_TYPE }, .func = &parse_to_wideint },
    .{ .name = "parse_to_float", .params = &.{.string}, .ret_type = .{ .nullable = &FLOAT_TYPE }, .func = &parse_to_float },
    .{ .name = "parse_to_double", .params = &.{.string}, .ret_type = .{ .nullable = &DOUBLE_TYPE }, .func = &parse_to_double },
    .{ .name = "fetch", .params = &.{.string}, .ret_type = .{ .nullable = &FETCH_RESULT_SEMA }, .func = &fetch },
    .{ .name = "type_of", .params = &.{.any}, .ret_type = .string, .func = &type_of },
};

pub fn initBuiltinTypes(allocator: std.mem.Allocator) !void {
    const names = [_][]const u8{ "url", "status", "body" };
    const types = [_]SemaType{ .string, .int, .string };

    const fields = try allocator.alloc(SemaType.Struct.Field, names.len);
    var map: std.StringHashMap(u32) = .init(allocator);

    for (names, types, 0..) |n, t, i| {
        const tp = try allocator.create(SemaType);
        tp.* = t;
        fields[i] = .{
            .name = n,
            .sema_type = tp,
            .mutability = .final, // TODO: use your real enum value
            .span = .empty(),
        };
        try map.put(n, @intCast(i));
    }

    FETCH_RESULT_STRUCT = .{ .name = "FetchResult", .fields = fields, .name_index_map = map };
}

var FETCH_RESULT_DESC: StructDesc = .{
    .name = "FetchResult",
    .field_names = &.{ "url", "status", "body" },
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
    try writeArgs(ctx.out, &vm.object_heap, args[0]);
    return unit;
}

fn println(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    try writeArgs(ctx.out, &vm.object_heap, args[0]);
    try ctx.out.writeByte('\n');
    return unit;
}

fn parse_to_int(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    _ = ctx;
    const str_obj = vm.object_heap.objects.items[args[0].heap_ref].string;
    const v = std.fmt.parseInt(i64, str_obj.bytes, 10) catch return singleton.IGLOT__NULL;
    return .{ .int = v };
}

fn parse_to_wideint(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    _ = ctx;
    const str_obj = vm.object_heap.objects.items[args[0].heap_ref].string;
    const v = std.fmt.parseInt(i128, str_obj.bytes, 10) catch return singleton.IGLOT__NULL;
    return .{ .wideint = v };
}

fn parse_to_float(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    _ = ctx;
    const str_obj = vm.object_heap.objects.items[args[0].heap_ref].string;
    const v = std.fmt.parseFloat(f32, str_obj.bytes) catch return singleton.IGLOT__NULL;
    return .{ .float = v };
}

fn parse_to_double(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    _ = ctx;
    const str_obj = vm.object_heap.objects.items[args[0].heap_ref].string;
    const v = std.fmt.parseFloat(f64, str_obj.bytes) catch return singleton.IGLOT__NULL;
    return .{ .double = v };
}

fn prompt(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    try writeValue(ctx.out, &vm.object_heap, args[0], false);
    try ctx.out.flush();

    var aw: std.Io.Writer.Allocating = .init(ctx.gpa);
    defer aw.deinit();

    _ = ctx.in.streamDelimiter(&aw.writer, '\n') catch |err| switch (err) {
        error.EndOfStream => {},
        error.ReadFailed => return error.ReadFailed,
        error.WriteFailed => return error.OutOfMemory,
    };

    if (ctx.in.bufferedLen() > 0) ctx.in.toss(1);

    // trim windows newline
    const trimmed = std.mem.trimEnd(u8, aw.written(), "\r");

    const ref = try vm.object_heap.createString(trimmed);
    return .{ .heap_ref = ref };
}

fn fetch(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    const gpa = ctx.gpa;
    const url = vm.object_heap.resolveRef(args[0].heap_ref).string.bytes;

    var client: std.http.Client = .{ .allocator = gpa, .io = ctx.io };
    defer client.deinit();

    var body: std.Io.Writer.Allocating = .init(gpa);
    defer body.deinit();

    const res = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &body.writer,
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return singleton.IGLOT__NULL, // network/TLS/URI errors
    };

    const heap = &vm.object_heap;
    var fields = [_]IglotValue{
        .{ .heap_ref = try heap.createString(url) },
        .{ .int = @backingInt(res.status) },
        .{ .heap_ref = try heap.createString(body.written()) },
    };
    return .{ .heap_ref = try heap.createStructInit(&FETCH_RESULT_DESC, &fields) };
}

fn type_of(vm: *IglotVM, ctx: *Context, args: []const IglotValue) BuiltinIglotFunctionError!IglotValue {
    var aw: std.Io.Writer.Allocating = .init(ctx.gpa);
    defer aw.deinit();

    try writeTypeName(&aw.writer, vm, args[0]);
    const ref = try vm.object_heap.createString(aw.written());
    return .{ .heap_ref = ref };
}

fn writeTypeName(out: *std.Io.Writer, vm: *IglotVM, v: IglotValue) std.Io.Writer.Error!void {
    switch (v) {
        .int => try out.writeAll("int"),
        .wideint => try out.writeAll("wideint"),
        .float => try out.writeAll("float"),
        .double => try out.writeAll("double"),
        .bool => try out.writeAll("bool"),
        .null => try out.writeAll("null"),
        .builtin_ref => try out.writeAll("builtin_function"),
        .func => try out.writeAll("function"),
        .heap_ref => |ref| switch (vm.object_heap.resolveRef(ref).*) {
            .string => try out.writeAll("string"),
            .array => try out.writeAll("array"),
            .struct_init => |s| try out.writeAll(s.desc.name),
        },
    }
}

fn writeArgs(out: *std.Io.Writer, obj_heap: *ObjectHeap, args_value: IglotValue) std.Io.Writer.Error!void {
    const obj = obj_heap.resolveRef(args_value.heap_ref);
    const elems = obj.array.elements;

    for (elems, 0..) |value, i| {
        if (i != 0) try out.writeAll(" ");
        try writeValue(out, obj_heap, value, false);
    }
}

fn writeHeapValue(out: *std.Io.Writer, obj_heap: *ObjectHeap, obj: *Object, nested: bool) !void {
    switch (obj.*) {
        .string => |s| {
            if (nested) {
                try out.writeAll("\"");
                try out.writeAll(s.bytes);
                try out.writeAll("\"");
                return;
            }
            try out.writeAll(s.bytes);
        },
        .array => |a| {
            if (a.elements.len == 0) {
                try out.writeAll("{}");
                return;
            }

            const is_array = switch (a.elements[0]) {
                .heap_ref => |r| blk: {
                    const v = obj_heap.resolveRef(r);
                    break :blk v.* == .array;
                },
                else => false,
            };

            try out.writeAll("{");
            if (is_array)
                try out.writeAll(" ");

            for (a.elements, 0..) |value, i| {
                try writeValue(out, obj_heap, value, true);
                if (a.elements.len > i + 1) {
                    try out.writeAll(", ");
                }
            }

            if (is_array)
                try out.writeAll(" ");
            try out.writeAll("}");
        },
        .struct_init => |s| {
            try out.writeAll(s.desc.name);

            if (s.fields.len == 0) {
                try out.writeAll(": {}");
                return;
            }

            try out.writeAll(" { ");
            for (s.fields, s.desc.field_names, 0..) |value, name, i| {
                if (i != 0) try out.writeAll(", ");
                try out.print("{s} = ", .{name});
                try writeValue(out, obj_heap, value, true);
            }
            try out.writeAll(" }");
        },
    }
}

fn writeValue(out: *std.Io.Writer, obj_heap: *ObjectHeap, v: IglotValue, nested: bool) std.Io.Writer.Error!void {
    switch (v) {
        .int => |x| try out.print("{d}", .{x}),
        .wideint => |x| try out.print("{d}", .{x}),
        .float => |x| try writeFloat(out, x),
        .double => |x| try writeFloat(out, x),
        .bool => |x| try out.writeAll(if (x == 1) "true" else "false"),
        .func => |id| try out.print("<fn [{d}]>", .{id}),
        .builtin_ref => |ref| try out.print("<builtin fn [{d}]>", .{ref}),
        .null => try out.writeAll("null"),
        .heap_ref => |ref| {
            const val = obj_heap.resolveRef(ref);
            try writeHeapValue(out, obj_heap, val, nested);
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
