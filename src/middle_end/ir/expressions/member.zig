const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildMemberExpr(ir: *IglotIR, allocator: std.mem.Allocator, m: *const typed_ast.TypedMemberExpr) !?inst.VReg {
    const obj_ref = try ir.buildExpression(allocator, m.object) orelse return null;

    // sema already validated this, so we can assery active type
    const struct_type = m.object.sem_type.@"struct";
    const field_idx = struct_type.name_index_map.get(m.property.value) orelse unreachable;
    const field_type = struct_type.fields[field_idx].sema_type.*;

    const result = ir.current_fn.newVReg();
    const operands = try allocator.dupe(inst.VReg, &.{obj_ref});

    try ir.emit(allocator, .{
        .op = .struct_get,
        .sema_type = field_type,
        .result = result,
        .operands = operands,
        .data = .{ .field_index = field_idx },
    });

    return result;
}
