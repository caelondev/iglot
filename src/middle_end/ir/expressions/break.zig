const std = @import("std");
const ast = @import("../../../frontend/parser/ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildBreakExpr(self: *IglotIR, allocator: std.mem.Allocator, b: *const ast.BreakExpression) !?inst.VReg {
    _ = b;
    const top_loop = self.loop_stack.getLast();

    try self.emit(allocator, .{
        .data = .{ .branch_target = top_loop.break_block },
        .op = .br,
        .operands = &.{},
        .result = null,
        .sema_type = null,
    });

    // break is noreturn, it produces no value
    return null;
}
