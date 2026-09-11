const std = @import("std");
const FaruDiagnostic = @import("../../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateCallExpr(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    c: *const ast.CallExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const callee = try sema.validateExpression(allocator, c.callee, c.callee.span, null) orelse return null;

    if (callee.sem_type != .function) {
        try sema.reportError(allocator, .{
            .span = span,
            .kind = .{
                .NonCallableCallee = .{
                    .callee_type = callee.sem_type,
                },
            },
        });

        return null;
    }

    const callee_fn = callee.sem_type.function;

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
        const arg = try sema.validateExpression(allocator, a, a.span, null) orelse return null;

        if (!arg.sem_type.eql(param.*)) {
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
                .callee = callee,
                .arguments = try arg_sem_types.toOwnedSlice(allocator),
                .sema_type = callee_fn.return_type.*,
            },
        },
    };

    return node;
}
