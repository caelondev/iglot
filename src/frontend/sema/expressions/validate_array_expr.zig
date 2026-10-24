const std = @import("std");
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateArrayExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.ArrayExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    const full_type = try tt.SemaType.fromTypeExpressionAllowInfer(sema, allocator, a.element_type) orelse return null;

    const arr = switch (full_type) {
        .array => |t| t,
        else => return null,
    };

    const elem_type = arr.element_type;

    // only the outermost size may be inferred: [_][2]int ok, [_][_]int not
    if (elem_type.hasInfer()) {
        try sema.reportError(allocator, .{
            .span = span,
            .kind = .ArraySizeTypeInfer,
        });
        return null;
    }

    const size: tt.SemaArraySize = switch (arr.size) {
        .unknown => return null, // const-eval failed, already reported
        .infer => .{ .known = a.elements.len },
        .known => |n| blk: {
            if (n != a.elements.len) {
                try sema.reportError(allocator, .{
                    .span = span,
                    .kind = .{ .ArraySizeMismatch = .{
                        .expected = n,
                        .found = a.elements.len,
                    } },
                });
                return null;
            }
            break :blk .{ .known = n };
        },
    };

    const elems = try validateElements(sema, allocator, a.elements, elem_type) orelse return null;

    const result_type: tt.SemaType = .{ .array = .{
        .size = size,
        .element_type = elem_type,
    } };

    return try makeNode(allocator, span, result_type, elems);
}

/// bare `{ ... }` element. the type comes entirely from the expected type
pub fn validateAnonymousArray(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.AnonymousArrayExpression,
    span: Span,
    expected_type: ?tt.SemaType,
) anyerror!?*typed_ast.TypedExpr {
    const expected = expected_type orelse {
        try sema.reportError(allocator, .{ .span = span, .kind = .CannotInferLiteralType });
        return null;
    };

    const arr = switch (expected) {
        .array => |x| x,
        .err => return null, // already reported upstream
        else => {
            try sema.reportError(allocator, .{
                .span = span,
                .kind = .CannotInferLiteralType,
            });
            return null;
        },
    };

    switch (arr.size) {
        .known => |n| if (n != a.elements.len) {
            try sema.reportError(allocator, .{
                .span = span,
                .kind = .{
                    .ArraySizeMismatch = .{
                        .expected = n,
                        .found = a.elements.len,
                    },
                },
            });
            return null;
        },
        .infer => unreachable,
        .unknown => return null,
    }

    const elems = try validateElements(sema, allocator, a.elements, arr.element_type) orelse return null;
    return try makeNode(allocator, span, expected, elems);
}

/// shared by typed and bare literals. reports and returns null on failure
fn validateElements(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    elements: []*ast.Expression,
    elem_type: *tt.SemaType,
) anyerror!?[]*typed_ast.TypedExpr {
    var typed_elems: std.ArrayList(*typed_ast.TypedExpr) = .empty;

    for (elements) |expr| {
        const typed = try sema.validateExpression(allocator, expr, expr.span, elem_type.*) orelse return null;

        if (!elem_type.eql(typed.sem_type)) {
            try sema.reportError(allocator, .{
                .span = expr.span,
                .kind = .{ .TypeMismatch = .{
                    .expected = elem_type.*,
                    .found = typed.sem_type,
                } },
            });
            return null;
        }

        try typed_elems.append(allocator, typed);
    }

    return try typed_elems.toOwnedSlice(allocator);
}

fn makeNode(
    allocator: std.mem.Allocator,
    span: Span,
    ty: tt.SemaType,
    elems: []*typed_ast.TypedExpr,
) !*typed_ast.TypedExpr {
    const node = try allocator.create(typed_ast.TypedExpr);
    node.* = .{
        .span = span,
        .sem_type = ty,
        .kind = .{
            .array = .{
                .elements = elems,
                .sema_type = ty,
            },
        },
    };
    return node;
}
