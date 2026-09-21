const std = @import("std");
const ir = @import("instruction.zig");
const BasicBlock = @import("basic_block.zig").BasicBlock;
const Function = @import("function.zig").Function;
const Module = @import("module.zig").Module;

pub fn printModule(writer: *std.Io.Writer, module: Module) !void {
    try printGlobals(writer, module);
    for (module.functions.items) |function| {
        try printFunction(writer, function.*);
    }
}

pub fn printGlobals(writer: *std.Io.Writer, module: Module) !void {
    for (module.globals.items, 0..) |global, id| {
        try writer.print("global @{d} {s} : {f} = ", .{ id, global.name, global.sema_type });
        try printConstant(writer, global.initializer);
        try writer.writeAll("\n");
    }
    if (module.globals.items.len > 0) try writer.writeAll("\n");
}

pub fn printFunction(writer: *std.Io.Writer, func: Function) !void {
    try writer.print("fn {s}() {f} {{\n", .{ func.function_name, func.ret_type });
    for (func.blocks.items) |block| {
        try printBlock(writer, block.*);
    }
    try writer.writeAll("}\n");
}

pub fn printBlock(writer: *std.Io.Writer, block: BasicBlock) !void {
    try writer.print("@{s} ({d}):\n", .{ block.name, block.id.id });
    for (block.instructions.items) |instr| {
        try writer.writeAll("    ");
        try printInstruction(writer, instr);
    }
}

pub fn printInstruction(writer: *std.Io.Writer, instr: ir.Instruction) !void {
    if (instr.result) |r| {
        try writer.print("[{d}] = ", .{r.id});
    }

    try writer.writeAll(@tagName(instr.op));

    switch (instr.data) {
        .none => try printOperandList(writer, instr.operands, " ", ", "),

        .constant => |c| {
            try writer.writeAll(" ");
            try printConstant(writer, c);
        },

        .branch_target => |b| try writer.print(" bb{d}", .{b.id}),

        .index => |idx| try writer.print(" #{d}", .{idx}),

        .global => |g| {
            if (instr.operands.len > 0) {
                try writer.print(" @{d}, [{d}]", .{ g.id, instr.operands[0].id });
            } else {
                try writer.print(" @{d}", .{g.id});
            }
        },

        .cond_branch => |cb| {
            if (instr.operands.len > 0) {
                try writer.print(" [{d}], bb{d}, bb{d}", .{ instr.operands[0].id, cb.true_block.id, cb.false_block.id });
            } else {
                try writer.print(" bb{d}, bb{d}", .{ cb.true_block.id, cb.false_block.id });
            }
        },

        .call => |c| {
            try writer.print(" @{d}(", .{c.callee.id});
            try printOperandList(writer, instr.operands, "", ", ");
            try writer.writeAll(")");
        },
    }

    if (instr.sema_type) |ty| {
        try writer.print(" : {f}", .{ty});
    }

    try writer.writeAll("\n");
}

fn printOperandList(writer: *std.Io.Writer, operands: []const ir.VReg, first_sep: []const u8, sep: []const u8) !void {
    for (operands, 0..) |op, i| {
        try writer.writeAll(if (i == 0) first_sep else sep);
        try writer.print("[{d}]", .{op.id});
    }
}

fn printConstant(writer: *std.Io.Writer, c: ir.ConstantValue) !void {
    switch (c) {
        .int => |v| try writer.print("{d}", .{v}),
        .wideint => |v| try writer.print("{d}", .{v}),
        .float => |v| try writer.print("{d}", .{v}),
        .double => |v| try writer.print("{d}", .{v}),
        .string => |s| try writer.print("\"{s}\"", .{s}),
        .bool => |b| try writer.print("{}", .{b}),
        .func => |f| try writer.print("@fn {d}", .{f.id}),
    }
}
