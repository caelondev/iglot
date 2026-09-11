const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../sema/typed_ast.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildLoopStatement(ir: *FaruIR, allocator: std.mem.Allocator, l: typed_ast.TypedLoopStatement) !void {
    const loop_block = try ir.current_fn.newBlock(allocator, "loop.start");

    try ir.emit(allocator, .{
        .op = .br,
        .operands = &.{},
        .data = .{ .branch_target = loop_block },
        .result = null,
        .sema_type = null,
    });

    ir.goToBlock(ir.current_fn.getBlock(loop_block.id));
    try ir.buildStmt(allocator, .{ .scoped = l.body });

    try ir.emit(allocator, .{
        .op = .br,
        .operands = &.{},
        .data = .{ .branch_target = loop_block },
        .result = null,
        .sema_type = null,
    });
}
