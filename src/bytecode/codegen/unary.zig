const std = @import("std");
const i = @import("../../middle_end/ir/instruction.zig");
const bc = @import("../bytecode.zig");
const IglotCodegen = @import("../codegen.zig").IglotCodegen;
const SemaType = @import("../../frontend/sema/type_table.zig").SemaType;

pub fn unary(self: *IglotCodegen, allocator: std.mem.Allocator, inst: i.Instruction) !void {
    const op: bc.IglotOpcode = switch (inst.sema_type.?) {
        .int => .ig_neg_i,
        .wideint => .ig_neg_w,
        .float => .ig_neg_f,
        .double => .ig_neg_d,
        else => unreachable,
    };

    try self.emit(allocator, .rr(op, try self.reg(inst.result.?), try self.reg(inst.operands[0])));
}
