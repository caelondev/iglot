const std = @import("std");
const bc = @import("bytecode.zig");
const Module = @import("module.zig").Module;
const Function = @import("module.zig").Function;

pub fn dumpBytecode(writer: *std.Io.Writer, m: *const Module) !void {
    for (m.functions.items, 0..) |func, id| {
        try printFunction(writer, m, func, id);
        if (id + 1 != m.functions.items.len) try writer.writeByte('\n');
    }
}

pub fn printFunction(writer: *std.Io.Writer, m: *const Module, func: Function, id: usize) !void {
    try writer.print("fn @{d} {s} (params {d}, regs {d})\n", .{
        id, func.name, func.param_count, func.reg_count,
    });
    const end = functionEnd(m, func.code_start);
    for (m.code.items[func.code_start..end], func.code_start..) |ins, pc| {
        try printInstruction(writer, m, pc, ins);
    }
}

fn functionEnd(m: *const Module, start: u32) u32 {
    var end: u32 = @intCast(m.code.items.len);
    for (m.functions.items) |f| {
        if (f.code_start > start and f.code_start < end) end = f.code_start;
    }
    return end;
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
            try w.writeAll(", ");
            try printReg(w, ins.b);
            try w.print(", {d} args", .{ins.c});
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

fn printReg(w: *std.Io.Writer, reg: u16) !void {
    if (reg == bc.no_reg) {
        try w.writeByte('_');
    } else {
        try w.print("r{d}", .{reg});
    }
}

fn printBytes(writer: *std.Io.Writer, ins: bc.Instruction) !void {
    for (std.mem.asBytes(&ins), 0..) |byte, i| {
        if (i != 0) try writer.writeByte(' ');
        try writer.print("{X:0>2}", .{byte});
    }
}

// resolves pool indices and function ids so you don't cross reference by hand
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
