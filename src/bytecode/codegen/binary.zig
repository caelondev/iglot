const std = @import("std");
const i = @import("../../middle_end/ir/instruction.zig");
const bc = @import("../bytecode.zig");
const IglotCodegen = @import("../codegen.zig").IglotCodegen;
const SemaType = @import("../../frontend/sema/type_table.zig").SemaType;

pub fn binary(self: *IglotCodegen, allocator: std.mem.Allocator, inst: i.Instruction) !void {
    const cg_op = irToCgOpcode(inst);

    if (cg_op == .ig_eq_null or cg_op == .ig_ne_null) {
        try self.emit(allocator, .rr(
            cg_op,
            try self.reg(inst.result.?),
            try self.reg(inst.operands[0]),
        ));
        return;
    }

    try self.emit(allocator, .rrr(
        cg_op,
        try self.reg(inst.result.?),
        try self.reg(inst.operands[0]),
        try self.reg(inst.operands[1]),
    ));
}

pub fn irToCgOpcode(inst: i.Instruction) bc.IglotOpcode {
    if (inst.sema_type.? == .nullable) {
        switch (inst.op) {
            .cmp_eq => return .ig_eq_null,
            .cmp_ne => return .ig_ne_null,
            else => {},
        }
    }

    return switch (inst.op) {
        .add => dispatchOpcode(inst.sema_type.?, .ig_add_i, .ig_add_w, .ig_add_f, .ig_add_d, null),
        .sub => dispatchOpcode(inst.sema_type.?, .ig_sub_i, .ig_sub_w, .ig_sub_f, .ig_sub_d, null),
        .mul => dispatchOpcode(inst.sema_type.?, .ig_mul_i, .ig_mul_w, .ig_mul_f, .ig_mul_d, null),
        .div => dispatchOpcode(inst.sema_type.?, .ig_div_i, .ig_div_w, .ig_div_f, .ig_div_d, null),

        .cmp_eq => dispatchOpcode(inst.sema_type.?, .ig_eq_i, .ig_eq_w, .ig_eq_f, .ig_eq_d, .ig_eq_str),
        .cmp_ne => dispatchOpcode(inst.sema_type.?, .ig_ne_i, .ig_ne_w, .ig_ne_f, .ig_ne_d, .ig_ne_str),
        .cmp_le => dispatchOpcode(inst.sema_type.?, .ig_le_i, .ig_le_w, .ig_le_f, .ig_le_d, null),
        .cmp_ge => dispatchOpcode(inst.sema_type.?, .ig_ge_i, .ig_ge_w, .ig_ge_f, .ig_ge_d, null),
        .cmp_lt => dispatchOpcode(inst.sema_type.?, .ig_lt_i, .ig_lt_w, .ig_lt_f, .ig_lt_d, null),
        .cmp_gt => dispatchOpcode(inst.sema_type.?, .ig_gt_i, .ig_gt_w, .ig_gt_f, .ig_gt_d, null),

        else => unreachable,
    };
}

pub fn dispatchOpcode(
    val_type: SemaType,
    int: bc.IglotOpcode,
    w: bc.IglotOpcode,
    f: bc.IglotOpcode,
    d: bc.IglotOpcode,
    str: ?bc.IglotOpcode,
) bc.IglotOpcode {
    return switch (val_type) {
        .int => int,
        .wideint => w,
        .float => f,
        .double => d,
        .string => str.?,
        .nullable => |t| dispatchOpcode(t.*, int, w, f, d, str),

        .bool,
        .noreturn,
        .@"struct",
        .any,
        .array,
        .char,
        .constant,
        .err,
        .function,
        .null,
        .number,
        .void,
        => unreachable,
    };
}
