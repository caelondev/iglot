const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildVariableDecl(self: *IglotIR, allocator: std.mem.Allocator, v: *const typed_ast.TypedVariableDeclaration) !void {
    const value_reg = try self.buildExpression(allocator, v.value) orelse {
        // noreturn value, e.g. `x ::= break;`
        // no value to bind, block is already terminated by the break
        return;
    };

    try self.current_scope.declare(allocator, v.identifier.value, value_reg);
}
