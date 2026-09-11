const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildLoopStatement(ir: *FaruIR, allocator: std.mem.Allocator, l: typed_ast.TypedLoopStatement) !void {
    const loop_block = try ir.current_fn.newBlock(allocator, "loop.start");
    const end_block = try ir.current_fn.newBlock(allocator, "loop.end");

    try ir.emit(allocator, .{
        .op = .br,
        .operands = &.{},
        .data = .{ .branch_target = loop_block },
        .result = null,
        .sema_type = null,
    });

    ir.goToBlock(ir.current_fn.getBlock(loop_block.id));
    try ir.pushLoop(allocator, .{
        .break_block = end_block,
    });

    defer ir.popLoop();
    try ir.buildStmt(allocator, .{ .scoped = l.body });
    try ir.emit(allocator, .{
        .op = .br,
        .operands = &.{},
        .data = .{ .branch_target = loop_block },
        .result = null,
        .sema_type = null,
    });

    ir.goToBlock(ir.current_fn.getBlock(end_block.id));
}
