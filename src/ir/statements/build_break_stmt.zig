const std = @import("std");
const inst = @import("../instruction.zig");
const ast = @import("../../parser/ast.zig");
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildBreakStatement(ir: *FaruIR, allocator: std.mem.Allocator, b: ast.BreakStatement) !void {
    _ = ir;
    _ = allocator;
    _ = b;
}
