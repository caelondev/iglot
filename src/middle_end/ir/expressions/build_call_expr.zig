const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const tokens = @import("../../../frontend/lexer/tokens.zig");
const tt = @import("../../../frontend/sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildCallExpr(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, c: typed_ast.TypedCallExpr) !inst.ValueRef {
    const callee_val = try ir.buildExpr(allocator, c.callee.*);

    const operands = try allocator.alloc(inst.ValueRef, c.arguments.len);
    for (c.arguments, 0..) |arg, i| {
        operands[i] = try ir.buildExpr(allocator, arg.*);
    }

    const dest = ir.current_fn.newValue();
    try ir.emit(allocator, .{
        .op = .call,
        .sema_type = sema_type,
        .result = dest,
        .operands = operands,
        .data = .{ .call = .{ .callee = callee_val } },
    });

    return dest;
}
