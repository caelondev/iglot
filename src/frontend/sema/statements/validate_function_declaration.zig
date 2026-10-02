const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateFunctionDeclaration(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    f: *const ast.FunctionDeclarationStatement,
) anyerror!?typed_ast.TypedFunctionDeclarationStatement {
    // NOTE: the hoist pass already declared this function with its full type,
    // duplicate names are reported there. we just read the type back.
    const declared = sema.type_table.lookupIdentifier(f.identifier.value) orelse return null;
    const fn_type = switch (declared.sem_type) {
        .function => |ft| ft,
        else => return null,
    };
    const ret_sem_type: tt.SemaType = fn_type.return_type.*;

    const prev_ctx = sema.current_function_ctx;
    sema.current_function_ctx = .{ .return_type = ret_sem_type };
    defer sema.current_function_ctx = prev_ctx;

    try sema.type_table.enterScope(allocator);
    defer sema.type_table.leaveScope(allocator);

    var params = try allocator.alloc(typed_ast.TypedFunctionParameter, f.parameters.len);
    for (f.parameters, 0..) |param, i| {
        const param_sem_type: tt.SemaType = fn_type.parameters[i].*;

        try sema.type_table.declareIdentifier(allocator, param.identifier.value, .{
            .span = param.span,
            .sem_type = param_sem_type,
            .is_final = param.param_type.kind == .final,
        });

        params[i] = .{
            .identifier = param.identifier,
            .param_type = param_sem_type,
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
                .annotations = try allocator.dupe(IglotDiagnostic.Annotation, &.{
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

fn loopCanBreak(body: *const typed_ast.TypedScopedStatement) bool {
    for (body.typed_stmts) |*stmt| {
        if (stmtCanBreak(stmt)) return true;
    }

    return false;
}

fn alwaysReturns(stmt: *const typed_ast.TypedStmt) bool {
    return switch (stmt.*) {
        .return_stmt => true,
        .break_stmt, .expression, .variable_declaration, .function_decl => false,
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
        .loop => |l| !loopCanBreak(&l.body),
    };
}

fn stmtCanBreak(stmt: *const typed_ast.TypedStmt) bool {
    return switch (stmt.*) {
        .break_stmt => true,

        .block => |b| {
            for (b.typed_stmts) |*s| {
                if (stmtCanBreak(s)) return true;
            }
            return false;
        },

        .scoped => |s| {
            for (s.typed_stmts) |*st| {
                if (stmtCanBreak(st)) return true;
            }
            return false;
        },

        .if_stmt => |f| blk: {
            if (stmtCanBreak(f.consequence)) break :blk true;

            if (f.alternative) |alternative| {
                if (stmtCanBreak(alternative)) break :blk true;
            }

            break :blk false;
        },

        // A break inside this loop belongs to this inner loop,
        // not the loop we're currently analyzing.
        .loop => false,

        .return_stmt => true,
        .expression,
        .variable_declaration,
        .function_decl,
        => false,
    };
}
