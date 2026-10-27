const std = @import("std");
const bc = @import("bytecode.zig");
const Module = @import("module.zig").Module;
const Function = @import("module.zig").Function;
const builtins = @import("../vm/builtins.zig");

pub fn dumpBytecode(writer: *std.Io.Writer, m: *const Module) !void {
    try printConstants(writer, m);
    for (m.functions.items, 0..) |func, id| {
        try printFunction(writer, m, func, id);
        if (id + 1 != m.functions.items.len) try writer.writeByte('\n');
    }
}

// constant pool

fn printConstants(writer: *std.Io.Writer, m: *const Module) !void {
    const c = &m.constants;
    try poolGroup(writer, "int", "{d}", c.ints.items);
    try poolGroup(writer, "wideint", "{d}", c.wideints.items);
    try poolGroup(writer, "float", "{d}", c.floats.items);
    try poolGroup(writer, "double", "{d}", c.doubles.items);
    try poolGroup(writer, "string", "\"{s}\"", c.strings.items);
}

fn printPoolHeader(writer: *std.Io.Writer, title: []const u8, count: usize) !void {
    try writer.print("#pool {s} ({d}) $:\n", .{ title, count });
}

fn poolGroup(writer: *std.Io.Writer, title: []const u8, comptime fmt: []const u8, items: anytype) !void {
    if (items.len == 0) return;
    try printPoolHeader(writer, title, items.len);

    for (items, 0..) |item, i| {
        var buf: [64]u8 = undefined;
        var text = std.Io.Writer.fixed(&buf);
        text.print(fmt, .{item}) catch {}; // a value too long for the column just gets cut off
        try writer.print("{d:0>4} | {s:<28} | ", .{ i, text.buffered() });

        if (@TypeOf(item) == []const u8) {
            try writer.print("len {d}", .{item.len});
        } else {
            try writeHexBytes(writer, std.mem.asBytes(&item));
        }
        try writer.writeByte('\n');
    }
    try writer.writeByte('\n');
}

// functions

pub fn printFunction(writer: *std.Io.Writer, m: *const Module, func: Function, id: usize) !void {
    try writer.print("fn @{d} {s} (params {d}, regs {d})\n", .{
        id, func.name, func.param_count, func.reg_count,
    });
    for (func.code.items, 0..) |ins, pc| {
        try printInstruction(writer, m, pc, ins);
    }
}

pub fn printInstruction(writer: *std.Io.Writer, m: *const Module, pc: usize, ins: bc.Instruction) !void {
    // render the instruction text into a scratch buffer so it can be padded
    var buf: [64]u8 = undefined;
    var text = std.Io.Writer.fixed(&buf);
    try printText(&text, ins);

    try writer.print("{d:0>4} | {s:<28} | ", .{ pc, text.buffered() });
    try printBytes(writer, ins);
    try printComment(writer, m, ins);
    try writer.writeByte('\n');
}

fn printText(w: *std.Io.Writer, ins: bc.Instruction) !void {
    try w.print("{s:<12} ", .{bc.name(ins.op)});

    switch (ins.op) {
        .ig_jmp => try w.print("->{d:0>4}", .{ins.imm()}),

        .ig_jmp_if, .ig_jmp_ifnot => {
            try printReg(w, ins.a);
            try w.print(", ->{d:0>4}", .{ins.imm()});
        },

        .ig_call => {
            try printReg(w, ins.a);
            try w.print(", {d} args, ", .{ins.b});
            try printReg(w, ins.c);
        },

        .ig_array_pack => {
            try printReg(w, ins.a);
            try printReg(w, ins.b);
            try w.print("#{d}", .{ins.c});
        },

        .ig_load_global, .ig_store_global => {
            try printReg(w, ins.a);
            try w.print(", @{d}", .{ins.imm()});
        },

        .ig_load_fn, .ig_const_fn => {
            try printReg(w, ins.a);
            try w.print(", f{d}", .{ins.imm()});
        },

        .ig_const_bool => {
            try printReg(w, ins.a);
            try w.print(", {s}", .{if (ins.imm() != 0) "true" else "false"});
        },

        .ig_load_builtin_fn => {
            try printReg(w, ins.a);
            if (ins.b < builtins.table.len) {
                try w.print(", {s}, ", .{builtins.table[ins.b].name});
            } else {
                try w.print(", <bad builtin {d}> ", .{ins.b});
            }
        },

        // pool loads print a typed ref so they match the #pool groups
        .ig_const_i => try constRef(w, ins, "int"),
        .ig_const_w => try constRef(w, ins, "wideint"),
        .ig_const_f => try constRef(w, ins, "float"),
        .ig_const_d => try constRef(w, ins, "double"),
        .ig_const_str => try constRef(w, ins, "string"),

        else => switch (bc.format(ins.op)) {
            .n => {},
            .r => try printReg(w, ins.a),
            .rr => {
                try printReg(w, ins.a);
                try w.writeAll(", ");
                try printReg(w, ins.b);
            },
            .rrr => {
                try printReg(w, ins.a);
                try w.writeAll(", ");
                try printReg(w, ins.b);
                try w.writeAll(", ");
                try printReg(w, ins.c);
            },
            .ri => {
                try printReg(w, ins.a);
                try w.print(", #{d}", .{ins.imm()});
            },
            .i => try w.print("#{d}", .{ins.imm()}),
        },
    }
}

fn constRef(w: *std.Io.Writer, ins: bc.Instruction, comptime kind: []const u8) !void {
    try printReg(w, ins.a);
    try w.print(", " ++ kind ++ "[{d}]", .{ins.imm()});
}

fn printReg(w: *std.Io.Writer, reg: u16) !void {
    if (reg == bc.no_reg) {
        try w.writeByte('_');
    } else {
        try w.print("r{d}", .{reg});
    }
}

fn printBytes(writer: *std.Io.Writer, ins: bc.Instruction) !void {
    try writeHexBytes(writer, std.mem.asBytes(&ins));
}

fn writeHexBytes(writer: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes, 0..) |byte, i| {
        if (i != 0) try writer.writeByte(' ');
        try writer.print("{X:0>2}", .{byte});
    }
}

fn printComment(writer: *std.Io.Writer, m: *const Module, ins: bc.Instruction) !void {
    const idx = ins.imm();
    switch (ins.op) {
        .ig_const_i => try poolComment(writer, "{d}", m.constants.ints.items, idx),
        .ig_const_w => try poolComment(writer, "{d}", m.constants.wideints.items, idx),
        .ig_const_f => try poolComment(writer, "{d}", m.constants.floats.items, idx),
        .ig_const_d => try poolComment(writer, "{d}", m.constants.doubles.items, idx),
        .ig_const_str => try poolComment(writer, "\"{s}\"", m.constants.strings.items, idx),
        .ig_load_fn, .ig_const_fn => {
            if (idx < m.functions.items.len) {
                try writer.print("  ; {s}", .{m.functions.items[idx].name});
            } else {
                try writer.writeAll("  ; <bad function id>");
            }
        },
        else => {},
    }
}

fn poolComment(writer: *std.Io.Writer, comptime fmt: []const u8, items: anytype, idx: u32) !void {
    if (idx < items.len) {
        try writer.print("  ; " ++ fmt, .{items[idx]});
    } else {
        try writer.writeAll("  ; <bad pool index>");
    }
}
