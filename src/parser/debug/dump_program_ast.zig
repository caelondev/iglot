const std = @import("std");
const ast = @import("../ast.zig");
const Allocator = std.mem.Allocator;

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

fn dumpStmt(
    allocator: Allocator,
    out: *std.ArrayList(u8),
    depth: usize,
    stmt: ast.Statement,
) !void {
    switch (stmt) {
        .expression => |e| {
            try out.appendNTimes(allocator, ' ', depth * 2);
            try out.appendSlice(allocator, "ExpressionStatement:\n");

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
    switch (expr) {
        .integer => |i| {
            try out.print(allocator, "Integer: {d}\n", .{i.value});
        },
        .string => |s| {
            try out.print(allocator, "String: \"{s}\"\n", .{s.value});
        },
        .float => |f| {
            try out.print(allocator, "Float: {d}\n", .{f.value});
        },
        .identifier => |i| {
            try out.print(allocator, "Identifier: {s}\n", .{i.value});
        },
    }
}
