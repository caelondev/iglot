//! Copyright (C) 2026  caelondev
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU Affero General Public License as published
//! by the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU Affero General Public License for more details.
//!
//! You should have received a copy of the GNU Affero General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.
//!
//! Validates bare brace expressions.
//!
//! A bare brace expression is a `{ ... }` literal with no type of its own.
//! The parser only records its shape (empty, positional or named), so the
//! meaning of the literal comes entirely from the expected type that sema
//! passes down from its context: a typed declaration, a function argument,
//! a return type, or an enclosing literal.
//!
//!     {}                  // array or struct, decided by the expected type
//!     { 1, 2, 3 }         // positional, an array
//!     { name = "bob" }    // named, a struct
//!
//! Positional and empty literals take the array route. With an expected
//! array type the elements are checked against its element type and its
//! size, and `unbounded` sizes are resolved to the literal's real length.
//! Without one, the type is inferred from the first element, and every
//! other element must match it.
//!
//! Named literals take the struct route. With an expected struct type,
//! each field is checked against the declared field type, and missing,
//! duplicate and unknown fields are reported. `{}` against a struct type
//! is an empty struct init, so every field must have a default.
//!
//! A literal with nothing to infer from (`{}` with no expected type, or a
//! named literal with no expected type) is reported as
//! `CannotInferLiteralType`.

const std = @import("std");
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

const max_array_len: usize = std.math.maxInt(u32);
const no_elements: []*ast.Expression = &.{};

pub fn validateBareBraceExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    a: *const ast.BareBraceExpression,
    span: Span,
    expected_type: ?tt.SemaType,
) anyerror!?*typed_ast.TypedExpr {
    return switch (a.body) {
        // TODO(struct): use validateNamedRoute if expected type is a struct
        .empty => validateArrayRoute(sema, allocator, no_elements, span, expected_type),
        .positional => |elements| validateArrayRoute(sema, allocator, elements, span, expected_type),
        .named => |fields| validateNamedRoute(sema, allocator, fields, span, expected_type),
    };
}

/// `{}` and `{ a, b, c }`. checks against an expected array type when there
/// is one, otherwise infers from the elements.
fn validateArrayRoute(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    elements: []*ast.Expression,
    span: Span,
    expected_type: ?tt.SemaType,
) anyerror!?*typed_ast.TypedExpr {
    if (!try checkArrayLen(sema, allocator, elements.len, span)) return null;

    if (expected_type) |expected| switch (expected) {
        .array => |arr| return try checkAgainstArray(sema, allocator, elements, span, expected, arr),
        .err => return null,
        else => {}, // any / non-array: fall through to inference
    };

    return try inferArray(sema, allocator, elements, span);
}

/// `{ name = value, ... }`. TODO(struct): resolve expected_type to a struct
/// decl, then check missing / duplicate / unknown fields and each value
/// against its field type. add that arm before the fallthrough below.
fn validateNamedRoute(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    fields: []ast.BareBraceExpression.FieldInit,
    span: Span,
    expected_type: ?tt.SemaType,
) anyerror!?*typed_ast.TypedExpr {
    _ = fields;

    const expected = expected_type orelse {
        try sema.reportError(allocator, .{ .span = span, .kind = .CannotInferLiteralType });
        return null;
    };

    if (expected == .err) return null;

    try sema.reportError(allocator, .{
        .span = span,
        .kind = .{ .NamedFieldsRequireStruct = .{ .found = expected } },
    });
    return null;
}

fn checkAgainstArray(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    elements: []*ast.Expression,
    span: Span,
    expected: tt.SemaType,
    arr: tt.SemaType.Array,
) anyerror!?*typed_ast.TypedExpr {
    switch (arr.size) {
        .known => |n| if (n < elements.len) {
            try sema.reportError(allocator, .{
                .span = span,
                .kind = .{ .ArraySizeMismatch = .{
                    .expected = n,
                    .found = elements.len,
                } },
            });
            return null;
        },
        .unbounded => {},
        .infer => unreachable,
        .unknown => return null,
    }

    const elems = try validateElements(sema, allocator, elements, arr.element_type) orelse return null;

    // unbounded is a param-side constraint only. the literal itself always
    // has a concrete size, which is what the IR needs
    const result_type: tt.SemaType = if (arr.size == .unbounded)
        .{ .array = .{
            .size = .{ .known = elements.len },
            .element_type = arr.element_type,
        } }
    else
        expected;

    return try makeNode(allocator, span, result_type, elems);
}

fn inferArray(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    elements: []*ast.Expression,
    span: Span,
) anyerror!?*typed_ast.TypedExpr {
    if (elements.len == 0) {
        try sema.reportError(allocator, .{ .span = span, .kind = .CannotInferLiteralType });
        return null;
    }

    // first element with no expected type decides the elem type
    const first = try sema.validateExpression(allocator, elements[0], elements[0].span, null) orelse return null;

    const elem_type = try allocator.create(tt.SemaType);
    elem_type.* = first.sem_type;

    var typed_elems: std.ArrayList(*typed_ast.TypedExpr) = .empty;
    try typed_elems.append(allocator, first);

    for (elements[1..]) |expr| {
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
        .size = .{ .known = elements.len },
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

        if (!elem_type.accepts(typed.sem_type)) {
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
