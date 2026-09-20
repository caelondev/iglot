const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildFunctionDecl(ir: *FaruIR, allocator: std.mem.Allocator, f: *const typed_ast.TypedFunctionDeclarationStatement) !?void {
    const func = try ir.module.createFunction(allocator, f.identifier.value, f.return_type);
    const entry_bb = try func.newBlock(allocator, "entry");
    ir.current_fn = func;
    ir.goToBlock(entry_bb);
    try ir.buildBodyStmt(allocator, f.body) orelse return null;

    if (!ir.current_block.isTerminated()) {
        // Sema guarantees only void functions can be unterminated,
        // so we implicitly inject ret_void when there's no explicit return.
        try ir.emit(allocator, .{
            .op = .ret_void,
            .sema_type = .void,
            .data = .none,
            .operands = &.{},
            .result = null,
        });
    }
}
