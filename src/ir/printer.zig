const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const Instruction = @import("instruction.zig").Instruction;

pub fn printModule(writer: *std.Io.Writer, module: Module) !void {
    for (module.functions.items) |func| {
        try printFunction(writer, func);
    }
}

fn printFunction(writer: *std.Io.Writer, func: Function) !void {
    try writer.print("fn {f} {s}(", .{ func.return_type, func.name });

    for (func.params, 0..) |p, i| {
        try writer.print("{s}: {f}", .{ p.name, p.sema_type });
        if (i != func.params.len - 1) {
            try writer.writeAll(", ");
        }
    }

    try writer.writeAll(") {\n");

    for (func.blocks.items) |block| {
        try printBlock(writer, block);
    }

    try writer.writeAll("}\n");
}

fn printBlock(writer: *std.Io.Writer, block: BasicBlock) !void {
    try writer.print("{s}:\n", .{block.name});

    for (block.instructions.items) |instr| {
        try writer.writeAll("  ");
        try printInstruction(writer, instr);
    }
}

fn printInstruction(writer: *std.Io.Writer, instr: Instruction) !void {
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
        .int_literal => |v| try writer.print(" {d}", .{v}),
        .wideint_literal => |v| try writer.print(" {d}", .{v}),
        .float_literal => |v| try writer.print(" {d}", .{v}),
        .double_literal => |v| try writer.print(" {d}", .{v}),
        .string_literal => |v| try writer.print(" \"{s}\"", .{v}),
        .branch_target => |b| try writer.print(" @{d}", .{b.id}),
        .cond_branch => |c| try writer.print(" @{d}, @{d}", .{
            c.true_block.id,
            c.false_block.id,
        }),
        .call => |c| try writer.print(" {s}", .{c.callee}),
        .index => |i| try writer.print(" {d}", .{i}),
    }

    for (instr.operands, 0..) |op, i| {
        try writer.writeAll(if (i == 0) " " else ", ");
        try writer.print("[{d}]", .{op.id});
    }

    try writer.writeByte('\n');
}
