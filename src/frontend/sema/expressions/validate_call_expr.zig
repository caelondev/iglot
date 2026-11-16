const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;
const builtins = @import("../../../vm/builtins.zig");

const ResolvedCallee = struct {
    callee: *typed_ast.TypedExpr,
    callee_kind: ast.CallExpression.CalleeKind,
};

pub fn validateCallExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    c: *const ast.CallExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const resolved = try resolveCallee(sema, allocator, c) orelse return null;

    if (resolved.callee.sem_type != .function) {
        try sema.reportError(allocator, .{
            .span = span,
            .kind = .{
                .NonCallableCallee = .{
                    .callee_type = resolved.callee.sem_type,
                },
            },
        });

        return null;
    }

    const callee_fn = resolved.callee.sem_type.function;

    if (callee_fn.parameters.len > c.arguments.len) {
        try sema.reportError(allocator, .{
            .span = span,
            .kind = .{
                .TooFewArguments = .{
                    .expected = callee_fn.parameters.len,
                    .found = c.arguments.len,
                },
            },
        });

        return null;
    }

    if (callee_fn.parameters.len < c.arguments.len) {
        try sema.reportError(allocator, .{
            .span = span,
            .kind = .{
                .TooManyArguments = .{
                    .expected = callee_fn.parameters.len,
                    .found = c.arguments.len,
                },
            },
        });

        return null;
    }

    var arg_sem_types: std.ArrayList(*typed_ast.TypedExpr) = .empty;

    for (c.arguments, callee_fn.parameters) |a, param| {
        const arg = try sema.validateExpression(allocator, a, a.span, param.*) orelse return null;

        if (!param.accepts(arg.sem_type)) {
            try sema.reportError(allocator, .{
                .span = arg.span,
                .kind = .{
                    .TypeMismatch = .{
                        .expected = param.*,
                        .found = arg.sem_type,
                    },
                },
            });

            return null;
        }

        try arg_sem_types.append(allocator, arg);
    }

    const node = try allocator.create(typed_ast.TypedExpr);
    node.* = .{
        .span = span,
        .sem_type = callee_fn.return_type.*,
        .kind = .{
            .call = .{
                .callee = resolved.callee,
                .callee_kind = resolved.callee_kind,
                .arguments = try arg_sem_types.toOwnedSlice(allocator),
                .sema_type = callee_fn.return_type.*,
            },
        },
    };

    return node;
}

fn resolveCallee(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    c: *const ast.CallExpression,
) anyerror!?ResolvedCallee {
    switch (c.callee_kind) {
        .defined => {
            const callee = try sema.validateExpression(allocator, c.callee, c.callee.span, null) orelse return null;
            return .{ .callee = callee, .callee_kind = .defined };
        },
        .builtin => {
            const name = switch (c.callee.expr) {
                .identifier => |i| i.value,
                else => unreachable,
            };

            const idx = builtins.lookupBuiltin(name) orelse {
                try sema.reportError(allocator, .{
                    .span = c.callee.span,
                    .kind = .{ .UndefinedBuiltin = .{ .identifier = name } },
                });
                return null;
            };
            const builtin_fn_st = try builtins.table[idx].semaType(allocator);

            const node = try allocator.create(typed_ast.TypedExpr);
            node.* = .{
                .span = c.callee.span,
                .sem_type = .{ .function = builtin_fn_st.function },
                .kind = .{ .identifier = .{ .value = name, .mutability = .function } },
            };
            return .{ .callee = node, .callee_kind = .builtin };
        },
    }
}
