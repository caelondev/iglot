const std = @import("std");
const CiscoDiagnostic = @import("diagnostics.zig").CiscoDiagnostic;
const Span = @import("../lexer/tokens.zig").Span;
const InkDye = @import("inkdye");

const SpanLabel = struct {
    text: []const u8,
    width: usize,
};

pub fn renderDiagnostics(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    dye: *InkDye.RuntimeChameleon,
    source: []const u8,
    diagnostic: CiscoDiagnostic,
) !void {
    try formatSeverity(writer, dye, diagnostic.severity, diagnostic.kind);
    try writer.print(" {s} ", .{try dye.gray().bold().fmt("::", .{})});
    try diagnostic.kind.toMessage(writer);
    try writer.writeAll("\n\n");

    try renderSnippet(writer, allocator, dye, source, diagnostic);

    if (diagnostic.annotation) |a| {
        try writer.writeAll("\n");
        try formatAnnotation(writer, dye, a);
        try writer.writeAll("\n");
    }
}

fn renderSnippet(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    dye: *InkDye.RuntimeChameleon,
    source: []const u8,
    diagnostic: CiscoDiagnostic,
) !void {
    const span = diagnostic.span;
    const span_label = try formatSpan(allocator, span, dye);
    defer allocator.free(span_label.text);

    var lines = std.mem.splitScalar(u8, source, '\n');
    var line_number: usize = 1;
    const bar = try dye.gray().fmt(" | ", .{});

    try writer.splatByteAll(' ', span_label.width + 2);
    try writer.writeAll(bar);
    try writer.writeByte('\n');

    while (lines.next()) |line| : (line_number += 1) {
        if (line_number < span.line_start)
            continue;

        if (line_number > span.line_end)
            break;

        if (line_number == span.line_start) {
            try writer.print("  {s}{s}", .{ span_label.text, bar });
        } else {
            try writer.splatByteAll(' ', span_label.width + 2);
            try writer.writeAll(bar);
        }

        const larrow = try dye.redBright().fmt(">", .{});
        const rarrow = try dye.redBright().fmt("<", .{});
        if (span.line_start == span.line_end) {
            // single-line span
            const start = @min(span.column_start - 1, line.len);
            const end = @min(span.column_end - 1, line.len);

            try writer.writeAll(line[0..start]);
            try writer.writeAll(larrow);
            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[start..end]}));
            try writer.writeAll(rarrow);
            try writer.writeAll(line[end..]);
        } else if (line_number == span.line_start) {
            // first line of a multiline span
            const start = @min(span.column_start - 1, line.len);

            try writer.writeAll(line[0..start]);
            try writer.writeAll(larrow);
            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[start..]}));
        } else if (line_number == span.line_end) {
            // last line of a multiline span
            const end = @min(span.column_end - 1, line.len);

            try writer.writeAll(line[0..end]);
            try writer.writeAll(rarrow);
            try writer.writeAll(line[end..]);
        } else {
            // entire line is inside the span.
            try writer.writeAll(larrow);
            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line}));
            try writer.writeAll(rarrow);
        }

        try writer.writeByte('\n');
    }

    try writer.splatByteAll(' ', span_label.width + 2);
    try writer.writeAll(bar);
    try writer.writeByte('\n');
}

fn spanWidth(span: Span) usize {
    var w = std.fmt.count("{d}:{d}", .{ span.line_start, span.column_start });
    if (span.line_start == span.line_end) {
        if (span.column_start != span.column_end) {
            w += std.fmt.count("-{d}", .{span.column_end});
        }
    } else {
        w += std.fmt.count("-{d}:{d}", .{ span.line_end, span.column_end });
    }
    return w;
}

fn formatSpan(
    allocator: std.mem.Allocator,
    span: Span,
    dye: *InkDye.RuntimeChameleon,
) !SpanLabel {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    try out.print(allocator, "{s}:{s}", .{
        try dye.cyan().bold().fmt("{d}", .{span.line_start}),
        try dye.cyan().bold().fmt("{d}", .{span.column_start}),
    });

    if (span.line_start == span.line_end) {
        if (span.column_start != span.column_end) {
            try out.print(allocator, "-{s}", .{
                try dye.cyan().bold().fmt("{d}", .{span.column_end}),
            });
        }
    } else {
        try out.print(allocator, "-{s}:{s}", .{
            try dye.cyan().bold().fmt("{d}", .{span.line_end}),
            try dye.cyan().bold().fmt("{d}", .{span.column_end}),
        });
    }

    return .{
        .text = try out.toOwnedSlice(allocator),
        .width = spanWidth(span),
    };
}

fn formatSeverity(
    writer: *std.Io.Writer,
    dye: *InkDye.RuntimeChameleon,
    severity: CiscoDiagnostic.Severity,
    kind: CiscoDiagnostic.Kind,
) !void {
    switch (severity) {
        .err => {
            const error_tag = try dye.red().bold().fmt("{s}", .{"error"});
            try writer.print("{s}[{s}]", .{ error_tag, @tagName(kind) });
        },
        .warning => try writer.writeAll(try dye.yellow().bold().fmt("warning", .{})),
    }
}

fn formatAnnotation(
    writer: *std.Io.Writer,
    dye: *InkDye.RuntimeChameleon,
    annotation: CiscoDiagnostic.Annotation,
) !void {
    const box_colon = try dye.gray().bold().fmt("::", .{});
    switch (annotation) {
        .help => |h| {
            const tag = try dye.yellow().bold().fmt("help", .{});
            try writer.print("{s} {s} {s}", .{ tag, box_colon, h.message });
        },
        .note => |n| {
            const tag = try dye.cyan().bold().fmt("note", .{});
            try writer.print("{s} {s} {s}", .{ tag, box_colon, n.message });
        },
    }
}
