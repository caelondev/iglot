const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildFunctionDecl(ir: *IglotIR, allocator: std.mem.Allocator, f: *const typed_ast.TypedFunctionDeclarationStatement) !?void {
    const prev_fn = ir.current_fn;
    const prev_block = ir.current_block;
    defer {
        ir.current_fn = prev_fn;
        ir.current_block = prev_block;
    }

    // NOTE: functions are already hoised, so we just retrieve
    // the function here
    const func = ir.module.getFunctionByName(f.identifier.value) orelse return null;
    const entry_bb = try func.newBlock(allocator, "entry");

    ir.current_fn = func;
    ir.goToBlock(entry_bb);

    try ir.current_scope.push(allocator);
    defer ir.current_scope.pop(allocator);

    for (func.params.items) |p| {
        const vreg = func.newVReg();
        try ir.emit(allocator, .{
            .op = .param,
            .sema_type = p.sema_type,
            .operands = try allocator.dupe(inst.VReg, &.{.{ .id = p.index }}),
            .data = .none,
            .result = vreg,
        });
        try ir.current_scope.declare(allocator, p.name, vreg);
    }

    try ir.buildBodyStmt(allocator, f.body) orelse return null;

    if (!ir.current_block.isTerminated()) {
        const op: inst.Opcode = if (f.return_type == .void) .ret_void else .@"unreachable";
        try ir.emit(allocator, .{
            .op = op,
            .sema_type = .void,
            .data = .none,
            .operands = &.{},
            .result = null,
        });
    }
}
