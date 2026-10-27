const std = @import("std");

pub const IglotOpcode = enum(u8) {
    // suffixes: i = int (i64), w = wideint (i128), f = float (f32), d = double (f64)
    ig_nop = 0x00,

    // arithmetic, one 16 slot block per type
    ig_add_i = 0x10,
    ig_sub_i = 0x11,
    ig_mul_i = 0x12,
    ig_div_i = 0x13,
    ig_mod_i = 0x14,
    ig_neg_i = 0x15,
    ig_add_w = 0x20,
    ig_sub_w = 0x21,
    ig_mul_w = 0x22,
    ig_div_w = 0x23,
    ig_mod_w = 0x24,
    ig_neg_w = 0x25,
    ig_add_f = 0x30,
    ig_sub_f = 0x31,
    ig_mul_f = 0x32,
    ig_div_f = 0x33,
    ig_mod_f = 0x34,
    ig_neg_f = 0x35,
    ig_add_d = 0x40,
    ig_sub_d = 0x41,
    ig_mul_d = 0x42,
    ig_div_d = 0x43,
    ig_mod_d = 0x44,
    ig_neg_d = 0x45,

    // logical (bools stored as 0/1)
    ig_not = 0x50,
    ig_and = 0x51,
    ig_or = 0x52,

    // comparisons, one 16 slot block per type (bool eq/ne reuse the _i versions)
    ig_lt_i = 0x60,
    ig_le_i = 0x61,
    ig_gt_i = 0x62,
    ig_ge_i = 0x63,
    ig_eq_i = 0x64,
    ig_ne_i = 0x65,
    ig_lt_w = 0x70,
    ig_le_w = 0x71,
    ig_gt_w = 0x72,
    ig_ge_w = 0x73,
    ig_eq_w = 0x74,
    ig_ne_w = 0x75,
    ig_lt_f = 0x80,
    ig_le_f = 0x81,
    ig_gt_f = 0x82,
    ig_ge_f = 0x83,
    ig_eq_f = 0x84,
    ig_ne_f = 0x85,
    ig_lt_d = 0x90,
    ig_le_d = 0x91,
    ig_gt_d = 0x92,
    ig_ge_d = 0x93,
    ig_eq_d = 0x94,
    ig_ne_d = 0x95,

    ig_eq_str = 0x96,
    ig_ne_str = 0x97,

    // data movement
    ig_mov = 0xA0,
    ig_load_global = 0xA1,
    ig_store_global = 0xA2,
    ig_load_fn = 0xA3,
    ig_load_builtin_fn = 0xD3,

    // constants (constant pool index, except bool)
    ig_const_i = 0xB0,
    ig_const_w = 0xB1,
    ig_const_f = 0xB2,
    ig_const_d = 0xB3,
    ig_const_str = 0xB4,
    ig_const_bool = 0xB5,
    ig_const_fn = 0xB6,

    // control flow
    ig_jmp = 0xC0,
    ig_jmp_if = 0xC1,
    ig_jmp_ifnot = 0xC2,
    ig_ret = 0xC3,
    ig_ret_void = 0xC4,

    // calls
    //   ig_call  a = window start: function id in r[a], arguments in r[a+1 .. a+b]
    //            b = argument count (a count, not a register)
    //            c = caller register that receives the result (no_reg for void)
    //   the callee's frame starts at r[a+1], so its r0 is argument 0
    ig_load_param = 0xD0,
    ig_call = 0xD1,

    //   ig_call_builtin  a = window start: r[a] unused, arguments in r[a+1 ..]
    //            b = builtin id (index into builtins.table, NOT an arg count)
    //            c = caller register that receives the result (no_reg for void)
    //            arg count comes from the table entry, not the instruction
    ig_call_builtin = 0xD2,
    ig_array_pack = 0xD4,

    // 0xE0 to 0xFE reserved for future stuff (casts, memory, structs, etc)

    ig_trap = 0xFF, // ir @"unreachable"

    const Self = @This();
    pub fn fromByte(byte: u8) Self {
        return @enumFromInt(byte);
    }
};

// every instruction is exactly 8 bytes.
//
//   byte 0      op
//   byte 1      reserved (0 for now, flags later)
//   bytes 2-3   a  (u16)
//   bytes 4-5   b  (u16)
//   bytes 6-7   c  (u16)
//
// imm32 overlaps b and c: imm = b | (c << 16)
//
// formats:
//   N    nothing
//   R    a
//   RR   a, b
//   RRR  a, b, c
//   RI   a, imm32
//   I    imm32
//
// jump targets are absolute instruction indices (not byte offsets), so
// pc += 1 steps one instruction and patching is just writing an index.

pub const no_reg: u16 = 0xFFFF; // "no destination", used by void calls

pub const OperandFormat = enum { n, r, rr, rrr, ri, i };

pub const Instruction = extern struct {
    op: IglotOpcode,
    reserved: u8 = 0,
    a: u16 = 0,
    b: u16 = 0,
    c: u16 = 0,

    comptime {
        std.debug.assert(@sizeOf(Instruction) == 8);
    }

    pub fn imm(self: Instruction) u32 {
        return @as(u32, self.b) | (@as(u32, self.c) << 16);
    }

    pub fn setImm(self: *Instruction, value: u32) void {
        self.b = @truncate(value);
        self.c = @truncate(value >> 16);
    }

    pub fn n(op: IglotOpcode) Instruction {
        return .{ .op = op };
    }
    pub fn r(op: IglotOpcode, a: u16) Instruction {
        return .{ .op = op, .a = a };
    }
    pub fn rr(op: IglotOpcode, a: u16, b: u16) Instruction {
        return .{ .op = op, .a = a, .b = b };
    }
    pub fn rrr(op: IglotOpcode, a: u16, b: u16, c: u16) Instruction {
        return .{ .op = op, .a = a, .b = b, .c = c };
    }
    pub fn ri(op: IglotOpcode, a: u16, value: u32) Instruction {
        var ins: Instruction = .{ .op = op, .a = a };
        ins.setImm(value);
        return ins;
    }
    pub fn i(op: IglotOpcode, value: u32) Instruction {
        return ri(op, 0, value);
    }
};

pub fn format(op: IglotOpcode) OperandFormat {
    return switch (op) {
        .ig_nop,
        .ig_ret_void,
        .ig_trap,
        => .n,

        .ig_ret,
        => .r,

        .ig_neg_i,
        .ig_neg_w,
        .ig_neg_f,
        .ig_neg_d,
        .ig_not,
        .ig_mov,
        => .rr,

        .ig_add_i,
        .ig_sub_i,
        .ig_mul_i,
        .ig_div_i,
        .ig_mod_i,
        .ig_add_w,
        .ig_sub_w,
        .ig_mul_w,
        .ig_div_w,
        .ig_mod_w,
        .ig_add_f,
        .ig_sub_f,
        .ig_mul_f,
        .ig_div_f,
        .ig_mod_f,
        .ig_add_d,
        .ig_sub_d,
        .ig_mul_d,
        .ig_div_d,
        .ig_mod_d,
        .ig_and,
        .ig_or,
        .ig_lt_i,
        .ig_le_i,
        .ig_gt_i,
        .ig_ge_i,
        .ig_eq_i,
        .ig_ne_i,
        .ig_lt_w,
        .ig_le_w,
        .ig_gt_w,
        .ig_ge_w,
        .ig_eq_w,
        .ig_ne_w,
        .ig_lt_f,
        .ig_le_f,
        .ig_gt_f,
        .ig_ge_f,
        .ig_eq_f,
        .ig_ne_f,
        .ig_lt_d,
        .ig_le_d,
        .ig_gt_d,
        .ig_ge_d,
        .ig_eq_d,
        .ig_ne_d,
        .ig_eq_str,
        .ig_ne_str,
        .ig_call,
        .ig_call_builtin,
        .ig_array_pack,
        => .rrr,

        .ig_load_global,
        .ig_store_global,
        .ig_load_fn,
        .ig_load_builtin_fn,
        .ig_load_param,
        .ig_const_i,
        .ig_const_w,
        .ig_const_f,
        .ig_const_d,
        .ig_const_str,
        .ig_const_bool,
        .ig_const_fn,
        .ig_jmp_if,
        .ig_jmp_ifnot,
        => .ri,

        .ig_jmp => .i,
    };
}

pub fn name(op: IglotOpcode) []const u8 {
    return @tagName(op)[3..]; // strip "ig_"
}
