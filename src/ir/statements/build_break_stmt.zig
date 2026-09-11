const std = @import("std");
const inst = @import("../instruction.zig");
const ast = @import("../../parser/ast.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildBreakStatement(ir: *FaruIR, allocator: std.mem.Allocator, b: ast.BreakStatement) !void {
    _ = b;
    const top_loop = ir.topLoopContext();

    try ir.emit(allocator, .{
        .op = .br,
        .data = .{ .branch_target = top_loop.break_block },
        .operands = &.{},
        .result = null,
        .sema_type = null,
    });
}
