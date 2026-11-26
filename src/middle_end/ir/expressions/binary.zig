const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const TokenKind = @import("../../../frontend/lexer/tokens.zig").TokenKind;
const inst = @import("../instruction.zig");
const IglotIR = @import("../ir.zig").IglotIR;

pub fn buildBinaryExpr(
    ir: *IglotIR,
    allocator: std.mem.Allocator,
    b: *const typed_ast.TypedBinaryExpr,
) !?inst.VReg {
    switch (b.operator) {
        .@"and", .@"or" => return buildLogicalExpr(ir, allocator, b),
        .or_else => return buildOrelseExpr(ir, allocator, b),
        else => {},
    }

    const op = tokenToOpcode(b.operator);
    const left_ref = try ir.buildExpression(allocator, b.left) orelse return null;
    const right_ref = try ir.buildExpression(allocator, b.right) orelse return null;
    const dest = ir.current_fn.newVReg();

    try ir.emit(allocator, .{
        .op = op,
        .sema_type = b.left.sem_type,
        .operands = try allocator.dupe(inst.VReg, &.{ left_ref, right_ref }),
        .result = dest,
        .data = .none,
    });

    return dest;
}

fn buildOrelseExpr(
    ir: *IglotIR,
    allocator: std.mem.Allocator,
    b: *const typed_ast.TypedBinaryExpr,
) !?inst.VReg {
    const dest = ir.current_fn.newVReg();
    const lhs = try ir.buildExpression(allocator, b.left) orelse return null;
    const null_reg = (try ir.loadSymbol(allocator, "null", .null)).reg;

    const rhs_block = try ir.current_fn.newBlock(allocator, "orelse.rhs");
    const not_null_block = try ir.current_fn.newBlock(allocator, "orelse.not_null");
    const merge_block = try ir.current_fn.newBlock(allocator, "orelse.merge");

    const is_null = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .op = .cmp_eq,
        .sema_type = b.left.sem_type,
        .operands = try allocator.dupe(inst.VReg, &.{ lhs, null_reg }),
        .result = is_null,
        .data = .none,
    });
    try ir.emit(allocator, .{
        .op = .cond_br,
        .sema_type = null,
        .operands = try allocator.dupe(inst.VReg, &.{is_null}),
        .result = null,
        .data = .{ .cond_branch = .{
            .true_block = rhs_block.id,
            .false_block = not_null_block.id,
        } },
    });

    ir.goToBlock(rhs_block);

    // if right is null, that means it diverges (emits a terminator)
    if (try ir.buildExpression(allocator, b.right)) |rhs| {
        try ir.emit(allocator, .{
            .op = .mov,
            .sema_type = b.left.sem_type,
            .operands = try allocator.dupe(inst.VReg, &.{rhs}),
            .result = dest,
            .data = .none,
        });
        try ir.emit(allocator, .{
            .op = .br,
            .sema_type = null,
            .operands = &.{},
            .result = null,
            .data = .{ .branch_target = merge_block.id },
        });
    }

    ir.goToBlock(not_null_block);
    try ir.emit(allocator, .{
        .op = .mov,
        .sema_type = b.left.sem_type,
        .operands = try allocator.dupe(inst.VReg, &.{lhs}),
        .result = dest,
        .data = .none,
    });
    try ir.emit(allocator, .{
        .op = .br,
        .sema_type = null,
        .operands = &.{},
        .result = null,
        .data = .{ .branch_target = merge_block.id },
    });

    ir.goToBlock(merge_block);
    return dest;
}

fn buildLogicalExpr(
    ir: *IglotIR,
    allocator: std.mem.Allocator,
    b: *const typed_ast.TypedBinaryExpr,
) !?inst.VReg {
    const is_and = b.operator == .@"and";

    const left_ref = try ir.buildExpression(allocator, b.left) orelse return null;

    const rhs_block = try ir.current_fn.newBlock(allocator, "logical.rhs");
    const short_block = try ir.current_fn.newBlock(allocator, "logical.short");
    const merge_block = try ir.current_fn.newBlock(allocator, "logical.merge");

    const rhs_ref = rhs_block.id;
    const short_ref = short_block.id;
    const merge_ref = merge_block.id;

    const dest = ir.current_fn.newVReg();

    try ir.emit(allocator, .{
        .op = .cond_br,
        .sema_type = b.left.sem_type,
        .operands = try allocator.dupe(inst.VReg, &.{left_ref}),
        .result = null,
        .data = .{
            .cond_branch = .{
                .true_block = if (is_and) rhs_ref else short_ref,
                .false_block = if (is_and) short_ref else rhs_ref,
            },
        },
    });

    // Short-circuit path.
    ir.goToBlock(short_block);

    try ir.emit(allocator, .{
        .op = .const_bool,
        .sema_type = b.left.sem_type,
        .operands = &.{},
        .result = dest,
        .data = .{
            .constant = .{
                .bool = !is_and,
            },
        },
    });

    try ir.emit(allocator, .{
        .op = .br,
        .sema_type = .void,
        .operands = &.{},
        .result = null,
        .data = .{
            .branch_target = merge_ref,
        },
    });

    // RHS path. This is only executed when required.
    ir.goToBlock(rhs_block);

    const right_ref = try ir.buildExpression(allocator, b.right) orelse return null;

    try ir.emit(allocator, .{
        .op = .mov,
        .sema_type = b.left.sem_type,
        .operands = try allocator.dupe(inst.VReg, &.{right_ref}),
        .result = dest,
        .data = .none,
    });

    try ir.emit(allocator, .{
        .op = .br,
        .sema_type = .void,
        .operands = &.{},
        .result = null,
        .data = .{
            .branch_target = merge_ref,
        },
    });

    // Continue after the logical expression.
    ir.goToBlock(merge_block);

    return dest;
}

fn tokenToOpcode(kind: TokenKind) inst.Opcode {
    return switch (kind) {
        .plus => .add,
        .minus => .sub,
        .asterisk => .mul,
        .slash => .div,

        .less => .cmp_lt,
        .less_equal_to => .cmp_le,
        .greater => .cmp_gt,
        .greater_equal_to => .cmp_ge,
        .equal_to => .cmp_eq,
        .not_equal_to => .cmp_ne,

        .@"and" => .@"and",
        .@"or" => .@"or",
        else => unreachable,
    };
}
