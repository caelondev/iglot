const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildReturnStmt(ir: *FaruIR, allocator: std.mem.Allocator, r: *const typed_ast.TypedReturnStatement) !?void {
    if (r.return_value == null) {
        try ir.emit(allocator, .{
            .op = .ret_void,
            .sema_type = .void,
            .data = .none,
            .operands = &.{},
            .result = null,
        });
        return;
    }

    const ret_val = r.return_value orelse unreachable;
    const dest = try ir.buildExpression(allocator, ret_val) orelse return null;
    try ir.emit(allocator, .{
        .op = .ret,
        .sema_type = ret_val.sem_type,
        .data = .none,
        .operands = try allocator.dupe(inst.VReg, &.{dest}),
        .result = null,
    });
}
