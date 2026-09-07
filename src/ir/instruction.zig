const std = @import("std");
const SemaType = @import("../sema/type_table.zig").SemaType;

pub const ValueRef = struct { id: u32 };
pub const BlockRef = struct { id: u32 };

pub const Opcode = enum {
    add,
    sub,
    mul,
    div,
    cmp_lt,
    cmp_gt,
    cmp_le,
    cmp_ge,
    cmp_eq,
    cmp_ne,
    alloca,
    load,
    store,
    br,
    cond_br,
    ret,
    ret_void,
    call,
    param,
    const_int,
    const_wideint,
    const_float,
    const_double,
    const_string,

    @"unreachable",
};

pub const Instruction = struct {
    op: Opcode,
    sema_type: ?SemaType,
    result: ?ValueRef,
    operands: []const ValueRef,
    data: Data,

    pub const Data = union(enum) {
        none: void,
        int_literal: i64,
        wideint_literal: i128,
        float_literal: f32,
        double_literal: f64,
        string_literal: []const u8,
        branch_target: BlockRef,
        index: usize,
        cond_branch: struct {
            true_block: BlockRef,
            false_block: BlockRef,
        },
        call: struct { callee: []const u8 },
    };
};
