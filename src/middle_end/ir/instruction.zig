const std = @import("std");
const SemaType = @import("../../frontend/sema/type_table.zig").SemaType;

pub const VReg = struct { id: u32 };

pub const BlockRef = struct { id: u32 };
pub const GlobalRef = struct { id: u32 };
pub const FunctionRef = struct { id: u32 };

pub const Opcode = enum {
    // arithmetic
    add,
    sub,
    mul,
    div,
    mod,
    neg,

    // logical
    not,
    @"and",
    @"or",

    // comparisons
    cmp_lt,
    cmp_le,
    cmp_gt,
    cmp_ge,
    cmp_eq,
    cmp_ne,

    // data movement
    mov,
    load_global,
    store_global,
    load_fn,

    // control flow
    br,
    cond_br,
    ret,
    ret_void,

    // calls
    call,
    param,

    // constants
    const_int,
    const_wideint,
    const_float,
    const_double,
    const_string,
    const_bool,
    const_fn,

    @"unreachable",
};

pub const Instruction = struct {
    op: Opcode,
    sema_type: ?SemaType,
    result: ?VReg,
    operands: []const VReg,
    data: Data,

    pub const Data = union(enum) {
        none: void,
        constant: ConstantValue,
        branch_target: BlockRef,
        index: usize,
        global: GlobalRef,
        cond_branch: struct {
            true_block: BlockRef,
            false_block: BlockRef,
        },
        call: struct { callee: VReg },
    };
};

pub const ConstantValue = union(enum) {
    int: i64,
    wideint: i128,
    float: f32,
    double: f64,
    string: []const u8,
    bool: bool,
    func: FunctionRef,
};

pub const Place = union(enum) {
    local: VReg,
    global: GlobalRef,
};

pub const Global = struct {
    name: []const u8,
    sema_type: SemaType,
};
