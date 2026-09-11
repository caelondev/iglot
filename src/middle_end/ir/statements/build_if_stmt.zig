const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildIfStatement(ir: *FaruIR, allocator: std.mem.Allocator, i: typed_ast.TypedIfStatement) !void {
    const cond_ref = try ir.buildExpr(allocator, i.condition.*);
    const true_block = try ir.current_fn.newBlock(allocator, "if.then");
    const false_block = try ir.current_fn.newBlock(allocator, "if.else");
    const end_block = try ir.current_fn.newBlock(allocator, "if.end");

    try ir.emit(allocator, .{
        .sema_type = null,
        .result = null,
        .op = .cond_br,
        .operands = try allocator.dupe(inst.ValueRef, &.{cond_ref}),
        .data = .{
            .cond_branch = .{
                .true_block = true_block,
                .false_block = false_block,
            },
        },
    });
    ir.goToBlock(ir.current_fn.getBlock(true_block.id));
    try ir.buildStmt(allocator, i.consequence.*);

    if (!ir.current_block.isTerminated()) {
        try ir.emit(allocator, .{
            .sema_type = null,
            .result = null,
            .op = .br,
            .operands = &.{},
            .data = .{
                .branch_target = end_block,
            },
        });
    }

    ir.goToBlock(ir.current_fn.getBlock(false_block.id));
    if (i.alternative) |a| {
        try ir.buildStmt(allocator, a.*);
    }

    if (!ir.current_block.isTerminated()) {
        try ir.emit(allocator, .{
            .sema_type = null,
            .result = null,
            .op = .br,
            .operands = &.{},
            .data = .{
                .branch_target = end_block,
            },
        });
    }

    ir.goToBlock(ir.current_fn.getBlock(end_block.id));
}
