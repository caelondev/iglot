const std = @import("std");
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

const max_array_len: usize = std.math.maxInt(u32);

pub fn validateArrayExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.ArrayExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    if (!try checkArrayLen(sema, allocator, a.elements.len, span)) return null;
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
            if (n < a.elements.len) {
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
    if (!try checkArrayLen(sema, allocator, a.elements.len, span)) return null;

    if (expected_type) |expected| switch (expected) {
        .array => |arr| return try checkAgainstArray(sema, allocator, a, span, expected, arr),
        .err => return null,
        else => {}, // any / non-array: fall through to inference
    };

    return try inferAnonymousArray(sema, allocator, a, span);
}

fn checkAgainstArray(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.AnonymousArrayExpression,
    span: Span,
    expected: tt.SemaType,
    arr: tt.SemaType.Array,
) anyerror!?*typed_ast.TypedExpr {
    switch (arr.size) {
        .known => |n| if (n != a.elements.len) {
            try sema.reportError(allocator, .{
                .span = span,
                .kind = .{ .ArraySizeMismatch = .{
                    .expected = n,
                    .found = a.elements.len,
                } },
            });
            return null;
        },
        .infer => unreachable,
        .unknown => return null,
    }

    const elems = try validateElements(sema, allocator, a.elements, arr.element_type) orelse return null;
    return try makeNode(allocator, span, expected, elems);
}

fn inferAnonymousArray(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.AnonymousArrayExpression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    if (a.elements.len == 0) {
        try sema.reportError(allocator, .{ .span = span, .kind = .CannotInferLiteralType });
        return null;
    }

    // first element with no expected type decides the elem type
    const first = try sema.validateExpression(allocator, a.elements[0], a.elements[0].span, null) orelse return null;

    const elem_type = try allocator.create(tt.SemaType);
    elem_type.* = first.sem_type;

    var typed_elems: std.ArrayList(*typed_ast.TypedExpr) = .empty;
    try typed_elems.append(allocator, first);

    for (a.elements[1..]) |expr| {
        // rest get checked against the first's type
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

    const result_type: tt.SemaType = .{ .array = .{
        .size = .{ .known = a.elements.len },
        .element_type = elem_type,
    } };

    return try makeNode(allocator, span, result_type, try typed_elems.toOwnedSlice(allocator));
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

/// array_new takes a u32 imm, so anything bigger can't be encoded.
/// reports and returns false if too big
pub fn checkArrayLen(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    len: i128,
    span: Span,
) !bool {
    if (len > max_array_len) {
        const message = try allocator.print(
            "bytecode instructions are a fixed 8 bytes and the array length lives in a 32-bit immediate, so the largest encodable length is {d}",
            .{max_array_len},
        );
        const notes = try allocator.dupe(IglotDiagnostic.Annotation, &.{.{ .note = .{
            .message = message,
        } }});

        try sema.reportError(allocator, .{
            .span = span,
            .kind = .{ .ArraySizeTooLarge = .{
                .found = len,
                .max = max_array_len,
            } },
            .annotations = notes,
        });
        return false;
    }
    return true;
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
