const std = @import("std");
const i = @import("../../middle_end/ir/instruction.zig");
const bc = @import("../bytecode.zig");
const IglotCodegen = @import("../codegen.zig").IglotCodegen;
const SemaType = @import("../../frontend/sema/type_table.zig").SemaType;

pub fn arithmetic(self: *IglotCodegen, allocator: std.mem.Allocator, inst: i.Instruction) !void {
    const cg_op = irToCgOpcode(inst);
    try self.emit(allocator, .rrr(
        cg_op,
        try self.reg(inst.result.?),
        try self.reg(inst.operands[0]),
        try self.reg(inst.operands[1]),
    ));
}

pub fn irToCgOpcode(inst: i.Instruction) bc.IglotOpcode {
    return switch (inst.op) {
        .add => dispatchOpcode(inst.sema_type.?, .ig_add_i, .ig_add_w, .ig_add_f, .ig_add_d),
        .sub => dispatchOpcode(inst.sema_type.?, .ig_sub_i, .ig_sub_w, .ig_sub_f, .ig_sub_d),
        .mul => dispatchOpcode(inst.sema_type.?, .ig_mul_i, .ig_mul_w, .ig_mul_f, .ig_mul_d),
        .div => dispatchOpcode(inst.sema_type.?, .ig_div_i, .ig_div_w, .ig_div_f, .ig_div_d),
        else => unreachable,
    };
}

pub fn dispatchOpcode(val_type: SemaType, int: bc.IglotOpcode, w: bc.IglotOpcode, f: bc.IglotOpcode, d: bc.IglotOpcode) bc.IglotOpcode {
    return switch (val_type) {
        .int => int,
        .wideint => w,
        .float => f,
        .double => d,
        else => unreachable,
    };
}
