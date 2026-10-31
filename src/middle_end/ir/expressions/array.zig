const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const SemaType = @import("../../../frontend/sema/type_table.zig").SemaType;
const inst = @import("../instruction.zig");
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildArrayExpr(ir: *IglotIR, allocator: std.mem.Allocator, a: *const typed_ast.TypedArrayExpr) !?inst.VReg {
    const dest = ir.current_fn.newVReg();

    const arr = a.sema_type.array;
    const arr_size: usize = @intCast(arr.size.known);
    const elems = try allocator.alloc(inst.VReg, arr_size);

    // evaluate every written element first. codegen moves them into a
    // consecutive window, so the vregs here don't need to be adjacent.
    for (a.elements, 0..) |elem, i| {
        elems[i] = try ir.buildExpression(allocator, elem) orelse return null;
    }

    // fewer elements than the size means zero init, fill the rest
    if (a.elements.len < arr_size) {
        const elem_ty = arr.element_type.*;

        if (elem_ty == .array) {
            // nested arrays need a fresh zero array per slot, otherwise
            // every slot would alias the same one
            for (a.elements.len..arr_size) |i| {
                elems[i] = try emitZero(ir, allocator, elem_ty);
            }
        } else {
            // scalars: emit the zero once and reuse the vreg
            const zero = try emitZero(ir, allocator, elem_ty);
            for (a.elements.len..arr_size) |i| elems[i] = zero;
        }
    }

    try ir.emit(allocator, .{
        .op = .array_pack,
        .sema_type = a.sema_type,
        .result = dest,
        .operands = elems,
        .data = .{ .size = elems.len },
    });

    return dest;
}

/// emits the zero value for a type and returns its vreg. nested arrays recurse.
fn emitZero(ir: *IglotIR, allocator: std.mem.Allocator, ty: SemaType) anyerror!inst.VReg {
    const dest = ir.current_fn.newVReg();

    switch (ty) {
        .int => try emitConst(ir, allocator, .const_int, ty, dest, .{ .int = 0 }),
        .wideint => try emitConst(ir, allocator, .const_wideint, ty, dest, .{ .wideint = 0 }),
        .float => try emitConst(ir, allocator, .const_float, ty, dest, .{ .float = 0.0 }),
        .double => try emitConst(ir, allocator, .const_double, ty, dest, .{ .double = 0.0 }),
        .bool => try emitConst(ir, allocator, .const_bool, ty, dest, .{ .bool = false }),
        .string => try emitConst(ir, allocator, .const_string, ty, dest, .{ .string = "" }),
        .array => |inner| {
            const n: usize = @intCast(inner.size.known);
            const elems = try allocator.alloc(inst.VReg, n);
            for (elems) |*slot| {
                slot.* = try emitZero(ir, allocator, inner.element_type.*);
            }
            try ir.emit(allocator, .{
                .op = .array_pack,
                .sema_type = ty,
                .result = dest,
                .operands = elems,
                .data = .{ .size = n },
            });
        },

        .any,
        .char,
        .constant,
        .err,
        .function,
        .number,
        .void,
        => unreachable, // sema should reject types with no zero value
    }

    return dest;
}

fn emitConst(
    ir: *IglotIR,
    allocator: std.mem.Allocator,
    op: inst.Opcode,
    ty: SemaType,
    dest: inst.VReg,
    value: inst.ConstantValue,
) !void {
    try ir.emit(allocator, .{
        .op = op,
        .sema_type = ty,
        .result = dest,
        .operands = &.{},
        .data = .{ .constant = value },
    });
}
