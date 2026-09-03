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
const InkDye = @import("inkdye");

pub fn dumpProgramAst(
    allocator: Allocator,
    dye: *InkDye.RuntimeChameleon,
    program: *ast.Program,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, try dye.bold().cyan().fmt("Program:", .{}));
    try out.append(allocator, '\n');

    for (program.body, 0..) |stmt, i| {
        try dumpStmt(allocator, &out, 1, stmt, dye);

        if (i != program.body.len - 1) {
            try out.append(allocator, '\n');
        }
    }

    return out.toOwnedSlice(allocator);
}

fn appendSpan(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    span: Span,
    dye: *InkDye.RuntimeChameleon,
) !void {
    try out.appendSlice(allocator, try dye.dim().fmt("[", .{}));

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

    try out.appendSlice(allocator, try dye.dim().fmt("]", .{}));
}

fn dumpStmt(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    depth: usize,
    stmt: ast.Statement,
    dye: *InkDye.RuntimeChameleon,
) !void {
    switch (stmt) {
        .expression => |e| {
            try out.appendNTimes(allocator, ' ', depth * 2);

            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("ExpressionStatement", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, e.span, dye);

            try out.appendSlice(allocator, ":\n");

            try dumpExpr(
                allocator,
                out,
                depth + 1,
                e.expression,
                dye,
            );
        },
    }
}

fn dumpExpr(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    depth: usize,
    expr: ast.Expression,
    dye: *InkDye.RuntimeChameleon,
) !void {
    try out.appendNTimes(allocator, ' ', depth * 2);

    switch (expr.expr) {
        .integer => |i| {
            try out.appendSlice(
                allocator,
                try dye.bold().yellow().fmt("Integer", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.print(allocator, ": {d}\n", .{i.value});
        },

        .string => |s| {
            try out.appendSlice(
                allocator,
                try dye.bold().green().fmt("String", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.print(allocator, ": \"{s}\"\n", .{s.value});
        },

        .float => |f| {
            try out.appendSlice(
                allocator,
                try dye.bold().yellow().fmt("Float", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.print(allocator, ": {d}\n", .{f.value});
        },

        .identifier => |i| {
            try out.appendSlice(
                allocator,
                try dye.bold().magenta().fmt("Identifier", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.print(allocator, ": {s}\n", .{i.value});
        },

        .unary => |u| {
            try out.appendSlice(
                allocator,
                try dye.bold().magenta().fmt("Operator", .{}),
            );

            try out.append(allocator, '\n');
            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try appendSpan(allocator, out, expr.span, dye);

            try out.print(allocator, ": {s}\n", .{@tagName(u.operator)});
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Right:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                u.rhs.*,
                dye,
            );
        },

        .binary => |b| {
            try out.appendSlice(
                allocator,
                try dye.bold().cyan().fmt("BinaryExpression", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.appendSlice(allocator, ":\n");

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Left:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                b.left.*,
                dye,
            );

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().yellow().fmt("Operator:", .{}),
            );

            try out.print(allocator, " {s}\n", .{
                @tagName(b.operator),
            });

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Right:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                b.right.*,
                dye,
            );
        },

        .assignment => |a| {
            try out.appendSlice(
                allocator,
                try dye.bold().cyan().fmt("AssignmentExpression", .{}),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.appendSlice(allocator, ":\n");

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Asignee:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                a.assignee.*,
                dye,
            );

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Value:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                a.value.*,
                dye,
            );
        },

        .variable_declaration => |v| {
            try out.appendSlice(
                allocator,
                try dye.bold().cyan().fmt(
                    "VariableDeclarationExpression",
                    .{},
                ),
            );

            try out.append(allocator, ' ');
            try appendSpan(allocator, out, expr.span, dye);

            try out.appendSlice(allocator, ":\n");

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Identifier:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                @as(ast.Expression, .{
                    .span = v.span,
                    .expr = .{
                        .identifier = v.identifier,
                    },
                }),
                dye,
            );

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().yellow().fmt("Type:", .{}),
            );

            try out.print(allocator, " {s}\n", .{
                v.type.identifier,
            });

            try out.appendNTimes(allocator, ' ', (depth + 1) * 2);
            try out.appendSlice(
                allocator,
                try dye.bold().blue().fmt("Value:", .{}),
            );
            try out.append(allocator, '\n');

            try dumpExpr(
                allocator,
                out,
                depth + 2,
                v.value.*,
                dye,
            );
        },
    }
}
