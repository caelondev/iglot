const std = @import("std");
const inst = @import("../instruction.zig");
const ast = @import("../../parser/ast.zig");
const tt = @import("../../sema/type_table.zig");
const CiscoIR = @import("../cisco_ir.zig").CiscoIR;

pub fn buildInteger(ir: *CiscoIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, i: ast.IntegerExpression) !inst.ValueRef {
    const result = ir.current_fn.newValue();

    const data: inst.Instruction.Data = switch (sema_type) {
        .wideint => .{ .wideint_literal = i.value },
        .int => .{ .int_literal = @intCast(i.value) },
        else => unreachable,
    };

    try ir.emit(allocator, .{
        .op = if (sema_type == .wideint) .const_wideint else .const_int,
        .sema_type = sema_type,
        .result = result,
        .operands = &.{},
        .data = data,
    });

    return result;
}
