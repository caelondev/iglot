const std = @import("std");
const bc = @import("../bytecode/bytecode.zig");
const Module = @import("../bytecode/module.zig").Module;

pub const IglotValue = extern union {
    int: i64,
    wideint: i128,
    float: f32,
    double: f64,
};

pub const CallFrame = struct {
    code: []const bc.Instruction, // what this frame executes, fetched with code[this.pc]
    pc: u32, // next instruction in that code
    base: u32, // where this frame's r0 sits in the shared register stack
    ret_reg: u16, // caller register that receives the result (bc.no_reg if unused)
    func: u32, // diagnostics only (traces, error messages), never read by the loop
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

    pub fn run(self: *Self, allocator: std.mem.Allocator, entry: u32) !void {
        _ = .{ self, allocator, entry };
        @panic("todo");
    }
};
