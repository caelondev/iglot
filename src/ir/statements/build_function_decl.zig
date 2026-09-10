const std = @import("std");
const inst = @import("../instruction.zig");
const typed_ast = @import("../../sema/typed_ast.zig");
const Function = @import("../function.zig").Function;
const FaruIR = @import("../faru_ir.zig").FaruIR;

pub fn buildFunction(ir: *FaruIR, allocator: std.mem.Allocator, decl: typed_ast.TypedFunctionDeclarationStatement) !void {
    const params = try allocator.alloc(Function.Param, decl.parameters.len);
    for (decl.parameters, 0..) |p, i| {
        params[i] = .{ .name = p.identifier.value, .sema_type = p.param_type };
    }

    const function_ref = ir.module.newFunction();
    const function = Function.init(function_ref, decl.identifier.value, params, decl.return_type);
    try ir.module.functions.append(allocator, function);
    try ir.functions.put(allocator, decl.identifier.value, function_ref);

    ir.current_fn = ir.module.currentFunction();

    const entry = try ir.current_fn.newBlock(allocator, "entry");
    ir.goToBlock(ir.current_fn.getBlock(entry.id));

    ir.locals.clearRetainingCapacity();

    for (decl.parameters, 0..) |p, i| {
        const param_val = ir.current_fn.newValue();
        try ir.emit(allocator, .{
            .op = .param,
            .sema_type = p.param_type,
            .operands = &.{},
            .result = param_val,
            .data = .{ .index = i },
        });

        const slot = ir.current_fn.newValue();
        try ir.emit(allocator, .{
            .op = .alloca,
            .sema_type = p.param_type,
            .operands = &.{},
            .result = slot,
            .data = .none,
        });

        try ir.emit(allocator, .{
            .op = .store,
            .sema_type = p.param_type,
            .operands = try allocator.dupe(inst.ValueRef, &.{ slot, param_val }),
            .result = null,
            .data = .none,
        });

        try ir.locals.put(allocator, p.identifier.value, slot);
    }

    try ir.buildStmt(allocator, .{ .block = decl.body });

    if (ir.current_block.isTerminated()) return;

    if (decl.return_type == .void) {
        try ir.emit(allocator, .{
            .op = .ret_void,
            .sema_type = null,
            .result = null,
            .operands = &.{},
            .data = .none,
        });
    } else {
        try ir.emit(allocator, .{
            .op = .@"unreachable",
            .sema_type = null,
            .result = null,
            .operands = &.{},
            .data = .none,
        });
    }
}
