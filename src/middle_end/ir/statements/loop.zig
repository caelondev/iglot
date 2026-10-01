const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildLoopStmt(self: *FaruIR, allocator: std.mem.Allocator, l: *const typed_ast.TypedLoopStatement) !?void {
    const loop_start_blk = try self.current_fn.newBlock(allocator, "loop.start");
    const loop_end_blk = try self.current_fn.newBlock(allocator, "loop.end");

    try self.emit(allocator, .{
        .op = .br,
        .data = .{ .branch_target = loop_start_blk.id },
        .operands = &.{},
        .result = null,
        .sema_type = null,
    });

    self.goToBlock(loop_start_blk);
    try self.pushLoopContext(allocator, .{
        .break_block = loop_end_blk.id,
    });

    defer {
        self.goToBlock(loop_end_blk);
        self.popLoopContext();
    }

    try self.buildScopedStmt(allocator, l.body) orelse return null;

    if (!self.current_block.isTerminated()) {
        try self.emit(allocator, .{
            .op = .br,
            .result = null,
            .sema_type = null,
            .data = .{ .branch_target = loop_start_blk.id },
            .operands = &.{},
        });
    }
}
