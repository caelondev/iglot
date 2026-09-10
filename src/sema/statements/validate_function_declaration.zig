const std = @import("std");
const FaruDiagnostic = @import("../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateFunctionDeclaration(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    f: *const ast.FunctionDeclarationStatement,
) anyerror!?typed_ast.TypedFunctionDeclarationStatement {
    if (sema.type_table.lookupCurrentScope(f.identifier.value)) |i| {
        const annotations = try allocator.dupe(FaruDiagnostic.Annotation, &.{
            .{
                .note = .{
                    .message = "identifier declared here",
                    .span = i.span,
                },
            },
        });

        try sema.reportError(allocator, .{
            .span = f.span,
            .severity = .err,
            .kind = .{
                .IdentifierAlreadyExist = .{
                    .identifier = f.identifier.value,
                },
            },
            .annotations = annotations,
        });

        return null;
    }

    const ret_sem_type: tt.SemaType = try tt.SemaType.fromTypeExpression(allocator, f.return_type) orelse return null;
    const ret_ptr = try allocator.create(tt.SemaType);
    ret_ptr.* = ret_sem_type;

    var param_sem_types = try allocator.alloc(*tt.SemaType, f.parameters.len);
    var param_sem_types_flat = try allocator.alloc(tt.SemaType, f.parameters.len);

    for (f.parameters, 0..) |param, i| {
        const param_sem_type = try tt.SemaType.fromTypeExpression(allocator, param.param_type) orelse return null;
        param_sem_types_flat[i] = param_sem_type;
        param_sem_types[i] = &param_sem_types_flat[i];
    }

    const function_sem_type: tt.SemaType = .{
        .function = .{
            .parameters = param_sem_types,
            .return_type = ret_ptr,
        },
    };

    const prev_ctx = sema.current_function_ctx;
    sema.current_function_ctx = .{ .return_type = ret_sem_type };
    defer sema.current_function_ctx = prev_ctx;

    try sema.type_table.declareIdentifier(allocator, f.identifier.value, .{
        .span = f.span,
        .sem_type = function_sem_type,
        .is_final = false,
    });

    try sema.type_table.enterScope(allocator);
    defer sema.type_table.leaveScope(allocator);

    var params = try allocator.alloc(typed_ast.TypedFunctionParameter, f.parameters.len);
    for (f.parameters, 0..) |param, i| {
        try sema.type_table.declareIdentifier(allocator, param.identifier.value, .{
            .span = param.span,
            .sem_type = param_sem_types_flat[i],
            .is_final = param.param_type.kind == .final,
        });

        params[i] = .{
            .identifier = param.identifier,
            .param_type = param_sem_types_flat[i],
            .span = param.span,
        };
    }

    const body = try sema.validateBlockStatement(allocator, &f.body) orelse return null;

    if (ret_sem_type != .void) {
        if (!alwaysReturns(&.{ .block = body })) {
            try sema.reportError(allocator, .{
                .span = f.span,
                .kind = .{
                    .MissingReturn = .{
                        .name = f.identifier.value,
                    },
                },
                .annotations = try allocator.dupe(FaruDiagnostic.Annotation, &.{
                    .{ .note = .{ .message = "not all control-flow paths returns a value" } },
                }),
            });
        }
    }

    return .{
        .identifier = f.identifier,
        .parameters = params,
        .body = body,
        .return_type = ret_sem_type,
        .span = f.span,
    };
}

fn alwaysReturns(stmt: *const typed_ast.TypedStmt) bool {
    return switch (stmt.*) {
        .expression => false,
        .function_decl => false,
        .return_stmt => true,
        .block => |b| blk: {
            for (b.typed_stmts) |*s| {
                if (alwaysReturns(s)) break :blk true;
            }
            break :blk false;
        },
        .scoped => |s| blk: {
            for (s.typed_stmts) |*st| {
                if (alwaysReturns(st)) break :blk true;
            }
            break :blk false;
        },
        .if_stmt => |f| blk: {
            if (f.alternative == null) break :blk false;
            break :blk alwaysReturns(f.consequence) and alwaysReturns(f.alternative.?);
        },
        .loop => blk: {
            break :blk true;
        },
    };
}
