const std = @import("std");
const bc = @import("../bytecode/bytecode.zig");
const Module = @import("../bytecode/module.zig").Module;

pub const IglotRuntimeError = error{
    NoCallFrame,
    DivisionByZero,
    UnimplementedOpcode,
} || std.mem.Allocator.Error;

pub const IglotValue = union(enum) {
    int: i64,
    wideint: i128,
    float: f32,
    double: f64,
    bool: u1,
    func: u32,
};

pub const CallFrame = struct {
    code: []const bc.Instruction, // what this frame executes, fetched with code[pc]
    pc: u32, // next instruction in that code
    base: u32, // where this frame's r0 sits in the shared register stack
    end: u32, // base + reg_count, so a return knows how far to shrink back
    ret_reg: u16, // caller register that receives the result (bc.no_reg if unused)
};

pub const IglotVM = struct {
    module: *const Module,
    globals: std.ArrayList(IglotValue),
    regs: std.ArrayList(IglotValue),
    frames: std.ArrayList(CallFrame),

    const Self = @This();

    pub fn init(module: *const Module) Self {
        return .{
            .module = module,
            .globals = .empty,
            .regs = .empty,
            .frames = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.globals.deinit(allocator);
        self.regs.deinit(allocator);
        self.frames.deinit(allocator);
    }

    pub fn run(self: *Self, allocator: std.mem.Allocator, entry: u32) !IglotValue {
        try self.globals.appendNTimes(allocator, undefined, self.module.global_count);
        if (self.module.init_fn) |f| _ = try self.execute(allocator, f);
        return self.execute(allocator, entry);
    }

    fn pushFrame(self: *Self, allocator: std.mem.Allocator, func_id: u32, base: u32, ret_reg: u16) !void {
        const func = &self.module.functions.items[func_id];
        const end = base + func.reg_count;
        if (end > self.regs.items.len) try self.regs.resize(allocator, end);
        try self.frames.append(allocator, .{
            .code = func.code.items,
            .pc = 0,
            .base = base,
            .end = end,
            .ret_reg = ret_reg,
        });
    }

    fn getCurrentFrame(self: *Self) !*CallFrame {
        if (self.frames.items.len == 0) return error.NoCallFrame;
        return &self.frames.items[self.frames.items.len - 1];
    }

    fn execute(self: *Self, allocator: std.mem.Allocator, func_id: u32) IglotRuntimeError!IglotValue {
        try self.pushFrame(allocator, func_id, 0, bc.no_reg);

        var frame = try self.getCurrentFrame();
        var regs = self.regs.items[frame.base..];
        const pool = &self.module.constants;

        while (true) {
            const ins = frame.code[frame.pc];
            frame.pc += 1;

            switch (ins.op) {
                .ig_const_i => regs[ins.a] = .{ .int = pool.ints.items[ins.imm()] },
                .ig_const_w => regs[ins.a] = .{ .wideint = pool.wideints.items[ins.imm()] },
                .ig_const_f => regs[ins.a] = .{ .float = pool.floats.items[ins.imm()] },
                .ig_const_d => regs[ins.a] = .{ .double = pool.doubles.items[ins.imm()] },
                .ig_const_bool => regs[ins.a] = .{ .int = ins.imm() },

                .ig_load_global => regs[ins.a] = self.globals.items[ins.imm()],
                .ig_store_global => self.globals.items[ins.imm()] = regs[ins.a],
                .ig_load_param => regs[ins.a] = regs[ins.imm()],

                .ig_add_i => regs[ins.a] = .{ .int = regs[ins.b].int +% regs[ins.c].int },
                .ig_sub_i => regs[ins.a] = .{ .int = regs[ins.b].int -% regs[ins.c].int },
                .ig_mul_i => regs[ins.a] = .{ .int = regs[ins.b].int *% regs[ins.c].int },
                .ig_div_i => regs[ins.a] = .{ .int = try divInt(i64, regs[ins.b].int, regs[ins.c].int) },

                .ig_add_w => regs[ins.a] = .{ .wideint = regs[ins.b].wideint +% regs[ins.c].wideint },
                .ig_sub_w => regs[ins.a] = .{ .wideint = regs[ins.b].wideint -% regs[ins.c].wideint },
                .ig_mul_w => regs[ins.a] = .{ .wideint = regs[ins.b].wideint *% regs[ins.c].wideint },
                .ig_div_w => regs[ins.a] = .{ .wideint = try divInt(i128, regs[ins.b].wideint, regs[ins.c].wideint) },

                .ig_add_f => regs[ins.a] = .{ .float = regs[ins.b].float + regs[ins.c].float },
                .ig_sub_f => regs[ins.a] = .{ .float = regs[ins.b].float - regs[ins.c].float },
                .ig_mul_f => regs[ins.a] = .{ .float = regs[ins.b].float * regs[ins.c].float },
                .ig_div_f => regs[ins.a] = .{ .float = regs[ins.b].float / regs[ins.c].float },

                .ig_add_d => regs[ins.a] = .{ .double = regs[ins.b].double + regs[ins.c].double },
                .ig_sub_d => regs[ins.a] = .{ .double = regs[ins.b].double - regs[ins.c].double },
                .ig_mul_d => regs[ins.a] = .{ .double = regs[ins.b].double * regs[ins.c].double },
                .ig_div_d => regs[ins.a] = .{ .double = regs[ins.b].double / regs[ins.c].double },

                .ig_lt_i => regs[ins.a] = cmp(.int, .lt, regs[ins.b], regs[ins.c]),
                .ig_le_i => regs[ins.a] = cmp(.int, .lte, regs[ins.b], regs[ins.c]),
                .ig_gt_i => regs[ins.a] = cmp(.int, .gt, regs[ins.b], regs[ins.c]),
                .ig_ge_i => regs[ins.a] = cmp(.int, .gte, regs[ins.b], regs[ins.c]),
                .ig_eq_i => regs[ins.a] = cmp(.int, .eq, regs[ins.b], regs[ins.c]),
                .ig_ne_i => regs[ins.a] = cmp(.int, .neq, regs[ins.b], regs[ins.c]),

                .ig_lt_w => regs[ins.a] = cmp(.wideint, .lt, regs[ins.b], regs[ins.c]),
                .ig_le_w => regs[ins.a] = cmp(.wideint, .lte, regs[ins.b], regs[ins.c]),
                .ig_gt_w => regs[ins.a] = cmp(.wideint, .gt, regs[ins.b], regs[ins.c]),
                .ig_ge_w => regs[ins.a] = cmp(.wideint, .gte, regs[ins.b], regs[ins.c]),
                .ig_eq_w => regs[ins.a] = cmp(.wideint, .eq, regs[ins.b], regs[ins.c]),
                .ig_ne_w => regs[ins.a] = cmp(.wideint, .neq, regs[ins.b], regs[ins.c]),

                .ig_lt_f => regs[ins.a] = cmp(.float, .lt, regs[ins.b], regs[ins.c]),
                .ig_le_f => regs[ins.a] = cmp(.float, .lte, regs[ins.b], regs[ins.c]),
                .ig_gt_f => regs[ins.a] = cmp(.float, .gt, regs[ins.b], regs[ins.c]),
                .ig_ge_f => regs[ins.a] = cmp(.float, .gte, regs[ins.b], regs[ins.c]),
                .ig_eq_f => regs[ins.a] = cmp(.float, .eq, regs[ins.b], regs[ins.c]),
                .ig_ne_f => regs[ins.a] = cmp(.float, .neq, regs[ins.b], regs[ins.c]),

                .ig_lt_d => regs[ins.a] = cmp(.double, .lt, regs[ins.b], regs[ins.c]),
                .ig_le_d => regs[ins.a] = cmp(.double, .lte, regs[ins.b], regs[ins.c]),
                .ig_gt_d => regs[ins.a] = cmp(.double, .gt, regs[ins.b], regs[ins.c]),
                .ig_ge_d => regs[ins.a] = cmp(.double, .gte, regs[ins.b], regs[ins.c]),
                .ig_eq_d => regs[ins.a] = cmp(.double, .eq, regs[ins.b], regs[ins.c]),
                .ig_ne_d => regs[ins.a] = cmp(.double, .neq, regs[ins.b], regs[ins.c]),

                .ig_mov => regs[ins.a] = regs[ins.b],
                .ig_jmp => frame.pc = ins.imm(),
                .ig_jmp_if => {
                    const cond = regs[ins.a].bool;
                    if (cond == 1) {
                        frame.pc = ins.imm();
                    }
                },
                .ig_jmp_ifnot => {
                    const cond = regs[ins.a].bool;
                    if (cond == 0) {
                        frame.pc = ins.imm();
                    }
                },

                .ig_load_fn, .ig_const_fn => regs[ins.a] = .{ .func = ins.imm() },
                .ig_call => {
                    const callee = regs[ins.a].func;
                    const new_base = frame.base + ins.a + 1; // skip callee

                    try self.pushFrame(allocator, callee, new_base, ins.c);

                    frame = try self.getCurrentFrame();
                    regs = self.regs.items[frame.base..];
                },

                .ig_ret, .ig_ret_void => {
                    const value: IglotValue = if (ins.op == .ig_ret) regs[ins.a] else .{ .int = 0 };

                    const done = self.frames.pop().?;
                    if (self.frames.items.len == 0) {
                        self.regs.shrinkRetainingCapacity(done.base);
                        return value;
                    }

                    frame = try self.getCurrentFrame();
                    self.regs.shrinkRetainingCapacity(frame.end);
                    regs = self.regs.items[frame.base..];
                    if (done.ret_reg != bc.no_reg) regs[done.ret_reg] = value;
                },

                .ig_nop => {},

                else => {
                    std.debug.print("vm: unimplemented opcode {s}\n", .{@tagName(ins.op)});
                    return error.UnimplementedOpcode;
                },
            }
        }
    }
};

const ValueKind = std.meta.Tag(IglotValue); // .int, .wideint, .float, .double, .func

fn cmp(comptime kind: ValueKind, comptime op: std.math.CompareOperator, a: IglotValue, b: IglotValue) IglotValue {
    const field = @tagName(kind);
    return .{ .bool = @intFromBool(std.math.compare(@field(a, field), op, @field(b, field))) };
}

fn divInt(comptime T: type, a: T, b: T) !T {
    if (b == 0) return error.DivisionByZero;
    if (b == -1) return 0 -% a; // minInt / -1 would overflow
    return @divTrunc(a, b);
}
