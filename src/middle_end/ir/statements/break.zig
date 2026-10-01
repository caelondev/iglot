const std = @import("std");
const ast = @import("../../../frontend/parser/ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildBreakStmt(self: *FaruIR, allocator: std.mem.Allocator, b: *const ast.BreakStatement) !?void {
    _ = b;
    const top_loop = self.loop_stack.getLast();
    try self.emit(allocator, .{
        .data = .{ .branch_target = top_loop.break_block },
        .op = .br,
        .operands = &.{},
        .result = null,
        .sema_type = null,
    });
}
