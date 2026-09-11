const std = @import("std");
const inst = @import("../instruction.zig");
const tokens = @import("../../../frontend/lexer/tokens.zig");
const ast = @import("../../../frontend/parser/ast.zig");
const tt = @import("../../../frontend/sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildInteger(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, i: ast.IntegerExpression) !inst.ValueRef {
    const result = ir.current_fn.newValue();

    const data: inst.Instruction.Data = switch (sema_type) {
        .wideint => .{ .constant = .{ .wideint = i.value } },
        .int => .{ .constant = .{ .int = @intCast(i.value) } },
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
