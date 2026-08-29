const std = @import("std");
const CiscoDiagnostic = @import("diagnostics.zig").CiscoDiagnostic;
const Span = @import("../lexer/tokens.zig").Span;

pub fn renderDiagnostics(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    source: []const u8,
    diagnostic: CiscoDiagnostic,
) !void {
    try formatSeverity(writer, diagnostic.severity, diagnostic.kind);
    try writer.writeAll(" :: ");
    try diagnostic.kind.toMessage(writer);
    try writer.writeAll("\n\n");

    try renderSnippet(writer, allocator, source, diagnostic);

    if (diagnostic.annotation) |a| {
        try writer.writeAll("\n");
        try formatAnnotation(writer, a);
        try writer.writeAll("\n");
    }
}

fn renderSnippet(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    source: []const u8,
    diagnostic: CiscoDiagnostic,
) !void {
    const span = diagnostic.span;

    const span_fmt = try formatSpan(allocator, span);
    defer allocator.free(span_fmt);

    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_number: usize = 1;

    try writer.splatByteAll(' ', span_fmt.len + 2);
    try writer.writeAll(" | ");
    try writer.writeByte('\n');

    while (lines.next()) |line| : (line_number += 1) {
        if (line_number < span.line_start)
            continue;

        if (line_number > span.line_end)
            break;

        if (line_number == span.line_start) {
            try writer.print("  {s} | ", .{span_fmt});
        } else {
            try writer.splatByteAll(' ', span_fmt.len + 2);
            try writer.writeAll(" | ");
        }

        if (span.line_start == span.line_end) {
            // single-line span
            const start = @min(span.column_start - 1, line.len);
            const end = @min(span.column_end - 1, line.len);

            try writer.writeAll(line[0..start]);
            try writer.writeByte('>');
            try writer.writeAll(line[start..end]);
            try writer.writeByte('<');
            try writer.writeAll(line[end..]);
        } else if (line_number == span.line_start) {
            // first line of a multiline span
            const start = @min(span.column_start - 1, line.len);

            try writer.writeAll(line[0..start]);
            try writer.writeByte('>');
            try writer.writeAll(line[start..]);
        } else if (line_number == span.line_end) {
            // last line of a multiline span
            const end = @min(span.column_end - 1, line.len);

            try writer.writeAll(line[0..end]);
            try writer.writeByte('<');
            try writer.writeAll(line[end..]);
        } else {
            // entire line is inside the span.
            try writer.writeByte('>');
            try writer.writeAll(line);
            try writer.writeByte('<');
        }

        try writer.writeByte('\n');
    }

    try writer.splatByteAll(' ', span_fmt.len + 2);
    try writer.writeAll(" | ");
    try writer.writeByte('\n');
}

fn formatSpan(
    allocator: std.mem.Allocator,
    span: Span,
) ![]const u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.print(allocator, "[{d}:{d}", .{
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

    return try out.toOwnedSlice(allocator);
}

fn formatSeverity(
    writer: *std.Io.Writer,
    severity: CiscoDiagnostic.Severity,
    kind: CiscoDiagnostic.Kind,
) !void {
    switch (severity) {
        .err => try writer.print("error[{s}]", .{@tagName(kind)}),
        .warning => try writer.writeAll("warning"),
    }
}

fn formatAnnotation(writer: *std.Io.Writer, annotation: CiscoDiagnostic.Annotation) !void {
    switch (annotation) {
        .help => |h| try writer.print("help :: {s}", .{h.message}),
        .note => |n| try writer.print("note :: {s}", .{n.message}),
    }
}
