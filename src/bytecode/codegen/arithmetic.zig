const std = @import("std");
const IglotCodegen = @import("../codegen.zig").IglotCodegen;
const i = @import("../../middle_end/ir/instruction.zig");

pub fn arithmetic(self: *IglotCodegen, op: i.Opcode, inst: i.Instruction) !void {
    _ = .{ self, op, inst };
}
