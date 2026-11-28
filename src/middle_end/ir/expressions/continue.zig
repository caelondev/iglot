const std = @import("std");
const ast = @import("../../../frontend/parser/ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildContinueExpr(self: *IglotIR, allocator: std.mem.Allocator, c: *const ast.ContinueExpression) !?inst.VReg {
    _ = c;
    const top_loop = self.loop_stack.getLast();

    try self.emit(allocator, .{
        .data = .{ .branch_target = top_loop.continue_block },
        .op = .br,
        .operands = &.{},
        .result = null,
        .sema_type = null,
    });

    // continue is noreturn, it produces no value
    return null;
}
