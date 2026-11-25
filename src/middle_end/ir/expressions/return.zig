const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildReturnExpr(ir: *IglotIR, allocator: std.mem.Allocator, r: *const typed_ast.TypedReturnExpression) !?inst.VReg {
    if (r.return_value == null) {
        try ir.emit(allocator, .{
            .op = .ret_void,
            .sema_type = .void,
            .data = .none,
            .operands = &.{},
            .result = null,
        });
        return null;
    }

    const ret_val = r.return_value orelse {
        // noreturn value, e.g. `x ::= break;`
        // no value to bind, block is already terminated by the break
        return null;
    };

    const dest = try ir.buildExpression(allocator, ret_val) orelse return null;
    try ir.emit(allocator, .{
        .op = .ret,
        .sema_type = ret_val.sem_type,
        .data = .none,
        .operands = try allocator.dupe(inst.VReg, &.{dest}),
        .result = null,
    });

    return null;
}
