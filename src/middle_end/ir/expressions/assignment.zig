const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildAssignmentExpr(ir: *FaruIR, allocator: std.mem.Allocator, a: *const typed_ast.TypedAssignment) !?inst.VReg {
    const rhs = try ir.buildExpression(allocator, a.value) orelse return null;
    const dest = ir.current_scope.resolve(a.assignee.kind.identifier.value) orelse unreachable;

    try ir.emit(allocator, .{
        .op = .mov,
        .sema_type = a.assignee.sem_type,
        .data = .none,
        .operands = try allocator.dupe(inst.VReg, &.{rhs}),
        .result = dest,
    });

    return dest;
}
