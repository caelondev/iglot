const std = @import("std");
const ast = @import("../../../frontend/parser/ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;
const tt = @import("../../../frontend/sema/type_table.zig");

pub fn buildIntegerLit(ir: *FaruIR, allocator: std.mem.Allocator, i: *const ast.IntegerExpression, sema_type: tt.SemaType) !?inst.VReg {
    const c: struct { inst.ConstantValue, inst.Opcode } = switch (sema_type) {
        .int => .{ .{ .int = @intCast(i.value) }, .const_int },
        .wideint => .{ .{ .wideint = i.value }, .const_wideint },
        else => unreachable,
    };

    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .constant = c[0] },
        .op = c[1],
        .operands = &.{},
        .result = dest,
        .sema_type = sema_type,
    });

    return dest;
}

pub fn buildWideIntegerLit(ir: *FaruIR, allocator: std.mem.Allocator, i: *const ast.WideIntegerExpression, sema_type: tt.SemaType) !?inst.VReg {
    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .constant = .{ .wideint = i.value } },
        .op = .const_wideint,
        .operands = &.{},
        .result = dest,
        .sema_type = sema_type,
    });

    return dest;
}

pub fn buildFloatLit(ir: *FaruIR, allocator: std.mem.Allocator, f: *const ast.FloatExpression, sema_type: tt.SemaType) !?inst.VReg {
    const c: struct { inst.ConstantValue, inst.Opcode } = switch (sema_type) {
        .float => .{ .{ .float = @floatCast(f.value) }, .const_float },
        .double => .{ .{ .double = f.value }, .const_double },
        else => unreachable,
    };

    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .constant = c[0] },
        .op = c[1],
        .operands = &.{},
        .result = dest,
        .sema_type = sema_type,
    });

    return dest;
}

pub fn buildStringLit(ir: *FaruIR, allocator: std.mem.Allocator, s: *const ast.StringExpression, sema_type: tt.SemaType) !?inst.VReg {
    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .data = .{ .constant = .{ .string = s.value } },
        .op = .const_string,
        .operands = &.{},
        .result = dest,
        .sema_type = sema_type,
    });

    return dest;
}
