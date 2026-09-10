const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../sema/typed_ast.zig");
const tokens = @import("../../lexer/tokens.zig");
const tt = @import("../../sema/type_table.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildVariableDecl(ir: *FaruIR, allocator: std.mem.Allocator, sema_type: tt.SemaType, v: typed_ast.TypedVariableDeclaration) !inst.ValueRef {
    const rhs_ref = try ir.buildExpr(allocator, v.value.*);

    const slot = ir.current_fn.newValue();
    try ir.emit(allocator, .{
        .op = .alloca,
        .sema_type = sema_type,
        .operands = &.{},
        .result = slot,
        .data = .none,
    });

    try ir.emit(allocator, .{
        .op = .store,
        .sema_type = sema_type,
        .operands = try allocator.dupe(inst.ValueRef, &.{ slot, rhs_ref }),
        .data = .none,
        .result = null,
    });

    try ir.locals.put(allocator, v.identifier.value, slot);
    return rhs_ref;
}
