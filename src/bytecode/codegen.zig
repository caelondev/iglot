const std = @import("std");
const bc = @import("bytecode.zig");
const Module = @import("module.zig").Module;
const IrModule = @import("../middle_end/ir/module.zig").Module;
const IrVReg = @import("../middle_end/ir/instruction.zig").VReg;
const IrInstruction = @import("../middle_end/ir/instruction.zig").Instruction;

const arithmetic = @import("codegen/arithmetic.zig").arithmetic;

pub const IglotCodegen = struct {
    module: Module,

    block_start: std.ArrayList(u32),
    current_fn_ref: u32,
    reg_count: u16,

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .block_start = .empty,
            .reg_count = 0,
            .current_fn_ref = 0,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.module.deinit(allocator);
        self.block_start.deinit(allocator);
    }

    pub fn generate(self: *Self, allocator: std.mem.Allocator, ir_module: *const IrModule) !*Module {
        _ = .{ ir_module, allocator };

        for (ir_module.functions.items) |f| {
            _ = try self.module.declareFunction(allocator, f.function_name, @intCast(f.params.items.len));
        }

        for (ir_module.functions.items, 0..) |f, i| {
            self.current_fn_ref = @intCast(i);
            self.reg_count = @intCast(f.params.items.len);

            for (f.blocks.items) |block| {
                for (block.instructions.items) |ins| {
                    try self.genInstruction(allocator, ins);
                }
            }

            self.module.functions.items[self.current_fn_ref].reg_count = self.reg_count;
        }

        const module = try allocator.create(Module);
        module.* = self.module;
        self.module = .init();
        return module;
    }

    pub fn reg(self: *Self, v: IrVReg) !u16 {
        if (v.id >= bc.no_reg)
            return error.RegisterLimitExceeded;

        const r: u16 = @intCast(v.id);
        self.reg_count = @max(self.reg_count, r + 1);
        return r;
    }

    fn genInstruction(self: *Self, allocator: std.mem.Allocator, ins: IrInstruction) !void {
        switch (ins.op) {
            .const_int, .const_wideint, .const_float, .const_double, .const_string, .const_bool, .const_fn => _ = try self.genConstant(allocator, ins),
            .ret => try self.emit(allocator, .r(.ig_ret, try self.reg(ins.operands[0]))),
            .ret_void => try self.emit(allocator, .n(.ig_ret_void)),
            .store_global => try self.emit(allocator, .ri(.ig_store_global, try self.reg(ins.operands[0]), ins.data.global.id)),
            .load_global => try self.emit(allocator, .ri(.ig_load_global, try self.reg(ins.result.?), ins.data.global.id)),
            .param => try self.emit(allocator, .ri(.ig_param, try self.reg(ins.result.?), ins.operands[0].id)),

            .add,
            .mul,
            .div,
            .sub,
            => |op| try arithmetic(self, op, ins),

            else => {
                std.debug.print("unimplemented ir op: {s}\n", .{@tagName(ins.op)});
                return error.UnimplementedOpcode;
            },
        }
    }

    fn genConstant(self: *IglotCodegen, allocator: std.mem.Allocator, ins: IrInstruction) !u16 {
        const dest = try self.reg(ins.result.?);
        const pool = &self.module.constants;
        const I = bc.Instruction;

        switch (ins.data.constant) {
            .int => |v| try self.emit(allocator, I.ri(.ig_const_i, dest, try pool.addInt(allocator, v))),
            .wideint => |v| try self.emit(allocator, I.ri(.ig_const_w, dest, try pool.addWideInt(allocator, v))),
            .float => |v| try self.emit(allocator, I.ri(.ig_const_f, dest, try pool.addFloat(allocator, v))),
            .double => |v| try self.emit(allocator, I.ri(.ig_const_d, dest, try pool.addDouble(allocator, v))),
            .string => |s| try self.emit(allocator, I.ri(.ig_const_str, dest, try pool.addString(allocator, s))),
            .bool => |b| try self.emit(allocator, I.ri(.ig_const_bool, dest, @intFromBool(b))),
            .func => |f| try self.emit(allocator, I.ri(.ig_const_fn, dest, f.id)),
        }

        return dest;
    }

    fn emit(self: *Self, allocator: std.mem.Allocator, inst: bc.Instruction) !void {
        _ = try self.module.emit(allocator, self.current_fn_ref, inst);
    }
};
