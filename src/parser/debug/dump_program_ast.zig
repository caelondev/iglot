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
//! Provides a human-readable representation of the Cisco abstract syntax
//! tree.
//!
//! The abstract syntax tree dumper traverses a program and writes its
//! structure to a newly allocated byte slice. Nodes are indented according
//! to their depth in the tree, making nested expressions and statement
//! structure visible.
//!
//! Each node is printed with its source span and relevant node data, such as
//! literal values, identifiers, and binary operators.
//!
//! `dumpProgramAst` is intended primarily for debugging and development.
//! Its output is a textual representation of the abstract syntax tree rather
//! than a serialization format and should not be relied upon for program data
//! interchange.

const std = @import("std");
const ast = @import("../ast.zig");
const Allocator = std.mem.Allocator;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn dumpProgramAst(
    allocator: Allocator,
    program: *ast.Program,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);

    try out.appendSlice(allocator, "Program:\n");

    for (program.body) |stmt| {
        try dumpStmt(allocator, &out, 1, stmt);
    }

    return out.toOwnedSlice(allocator);
}

fn appendSpan(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    span: Span,
) !void {
    try out.append(allocator, '[');
    try out.print(allocator, "{d}:{d}", .{
        span.line_start,
        span.column_start,
    });

    if (span.line_start == span.line_end) {
        if (span.column_start != span.column_end) {
            try out.print(allocator, "-{d}", .{
                span.column_end,
            });
        }
    } else {
        try out.print(allocator, "-{d}:{d}", .{
            span.line_end,
            span.column_end,
        });
    }
    try out.append(allocator, ']');
}

fn dumpStmt(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    depth: usize,
    stmt: ast.Statement,
) !void {
    switch (stmt) {
        .expression => |e| {
            try out.appendNTimes(allocator, ' ', depth * 2);
            try out.appendSlice(allocator, "ExpressionStatement ");
            try appendSpan(allocator, out, e.span);
            try out.appendSlice(allocator, ":\n");

            try dumpExpr(
                allocator,
                out,
                depth + 1,
                e.expression,
            );
        },
    }
}

fn dumpExpr(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    depth: usize,
    expr: ast.Expression,
) !void {
    try out.appendNTimes(allocator, ' ', depth * 2);

    switch (expr.expr) {
        .integer => |i| {
            try out.appendSlice(allocator, "Integer ");
            try appendSpan(allocator, out, expr.span);
            try out.print(allocator, ": {d}\n", .{i.value});
        },

        .string => |s| {
            try out.appendSlice(allocator, "String ");
            try appendSpan(allocator, out, expr.span);
            try out.print(allocator, ": \"{s}\"\n", .{s.value});
        },

        .float => |f| {
            try out.appendSlice(allocator, "Float ");
            try appendSpan(allocator, out, expr.span);
            try out.print(allocator, ": {d}\n", .{f.value});
        },

        .identifier => |i| {
            try out.appendSlice(allocator, "Identifier ");
            try appendSpan(allocator, out, expr.span);
            try out.print(allocator, ": {s}\n", .{i.value});
        },

        .binary => |b| {
            try out.appendSlice(allocator, "BinaryExpression ");
            try appendSpan(allocator, out, expr.span);
            try out.appendSlice(allocator, ":\n");

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(allocator, "Left:\n");

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                b.left.*,
            );

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.print(allocator, "Operator: {s}\n", .{
                @tagName(b.operator),
            });

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(allocator, "Right:\n");

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                b.right.*,
            );
        },
    }
}
