const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildIfStmt(ir: *FaruIR, allocator: std.mem.Allocator, i: *const typed_ast.TypedIfStatement) !?void {
    const cond_blk = try ir.current_fn.newBlock(allocator, "if.cond");
    const then_blk = try ir.current_fn.newBlock(allocator, "if.then");
    const alt_blk = try ir.current_fn.newBlock(allocator, "if.alt");

    try ir.emit(allocator, .{
        .data = .{
            .branch_target = cond_blk.id,
        },
        .op = .br,
        .operands = &.{},
        .result = null,
        .sema_type = null,
    });

    ir.goToBlock(cond_blk);
    const cond_ref = try ir.buildExpression(allocator, i.condition) orelse return null;

    try ir.emit(allocator, .{
        .data = .{
            .cond_branch = .{
                .true_block = then_blk.id,
                .false_block = alt_blk.id,
            },
        },
        .op = .br,
        .operands = try allocator.dupe(inst.VReg, &.{cond_ref}),
        .result = null,
        .sema_type = null,
    });

    ir.goToBlock(then_blk);
    try ir.buildStmt(allocator, i.consequence.*) orelse return null;

    ir.goToBlock(alt_blk);
    if (i.alternative) |alt| {
        try ir.buildStmt(allocator, alt.*) orelse return null;
    }
}
