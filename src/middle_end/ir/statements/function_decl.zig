const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const inst = @import("../instruction.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildFunctionDecl(ir: *FaruIR, allocator: std.mem.Allocator, f: *typed_ast.TypedFunctionDeclarationStatement) !void {
    const func = try ir.module.createFunction(allocator, f.identifier.value);
    const entry_bb = try func.newBlock("entry");
    ir.current_fn = func;
    ir.goToBlock(entry_bb);
    ir.buildBodyStmt(f.body);
}
