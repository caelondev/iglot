const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const Instruction = inst.Instruction;

pub fn printModule(writer: *std.Io.Writer, module: Module) !void {
    for (module.globals.items) |g| {
        try printGlobal(writer, g);
    }
    try writer.writeByte('\n');

    for (module.functions.items) |func| {
        try printFunction(writer, module.globals.items, func);
    }
}

fn printGlobal(writer: *std.Io.Writer, g: Module.GlobalVariable) !void {
    try writer.print("@{s} :: {f} = ", .{ g.name, g.sema_type });
    try printConstant(writer, g.initializer);
    try writer.writeByte('\n');
}

fn printFunction(writer: *std.Io.Writer, globals: []const Module.GlobalVariable, func: Function) !void {
    try writer.print("fn #{d} {s}(", .{ func.id.id, func.name });

    for (func.params, 0..) |p, i| {
        try writer.print("{s} :: {f}", .{ p.name, p.sema_type });
        if (i != func.params.len - 1) {
            try writer.writeAll(", ");
        }
    }

    try writer.print(") {f} {{\n", .{func.return_type});

    for (func.blocks.items) |block| {
        try printBlock(writer, globals, block);
    }

    try writer.writeAll("}\n");
}

fn printBlock(writer: *std.Io.Writer, globals: []const Module.GlobalVariable, block: *BasicBlock) !void {
    try writer.print("@{s} ({d}):\n", .{ block.name, block.id.id });

    for (block.instructions.items) |instr| {
        try writer.writeAll("  ");
        try printInstruction(writer, globals, instr);
    }
}

fn printConstant(writer: *std.Io.Writer, c: inst.ConstantValue) !void {
    switch (c) {
        .int => |v| try writer.print("{d}", .{v}),
        .wideint => |v| try writer.print("{d}", .{v}),
        .float => |v| try writer.print("{d}", .{v}),
        .double => |v| try writer.print("{d}", .{v}),
        .string => |v| try writer.print("\"{s}\"", .{v}),
        .bool => |v| try writer.print("{}", .{v}),
        .func => |f| try writer.print("{d}", .{f.id}),
    }
}

fn printInstruction(writer: *std.Io.Writer, globals: []const Module.GlobalVariable, instr: Instruction) !void {
    if (instr.result) |r| {
        try writer.print("[{d}]", .{r.id});

        if (instr.sema_type) |ty| {
            try writer.print(" :: {f}", .{ty});
        }

        try writer.writeAll(" = ");
    }

    try writer.writeAll(@tagName(instr.op));

    switch (instr.data) {
        .none => {},
        .constant => |c| {
            try writer.writeByte(' ');
            try printConstant(writer, c);
        },
        .branch_target => |b| try writer.print(" @{d}", .{b.id}),
        .index => |i| try writer.print(" {d}", .{i}),
        .global => |g| try writer.print(" @{s}", .{globals[g.id].name}),
        .cond_branch => |c| try writer.print(" @{d}, @{d}", .{
            c.true_block.id,
            c.false_block.id,
        }),
        .call => |c| try writer.print(" #{d}", .{c.callee.id}),
    }

    for (instr.operands, 0..) |op, i| {
        try writer.writeAll(if (i == 0) " " else ", ");
        try writer.print("[{d}]", .{op.id});
    }

    try writer.writeByte('\n');
}
