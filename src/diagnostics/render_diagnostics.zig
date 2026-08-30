const std = @import("std");
const CiscoDiagnostic = @import("diagnostics.zig").CiscoDiagnostic;
const Span = @import("../lexer/tokens.zig").Span;
const InkDye = @import("inkdye");

const TAB_WIDTH: usize = 4;

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

/// expand tabs into spaces at TAB_WIDTH-column tab stops. we do this
/// ourselves rather than relying on the terminal so that our column math
/// (bar alignment, highlight boundaries) matches what's actually printed.
fn expandTabs(allocator: std.mem.Allocator, line: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var col: usize = 0;
    for (line) |c| {
        if (c == '\t') {
            const spaces = TAB_WIDTH - (col % TAB_WIDTH);
            try out.appendNTimes(allocator, ' ', spaces);
            col += spaces;
        } else {
            try out.append(allocator, c);
            col += 1;
        }
    }
    return out.toOwnedSlice(allocator);
}

/// map a 0-based *character* offset in `line` (tabs count as 1, matching how
/// the lexer counts columns) to the corresponding 0-based *visual* column
/// after tab expansion. Used to translate span.column_start/column_end into
/// offsets we can slice the expanded line with.
fn visualCol(line: []const u8, char_offset: usize) usize {
    var visual: usize = 0;
    var i: usize = 0;
    while (i < char_offset and i < line.len) : (i += 1) {
        if (line[i] == '\t') {
            visual += TAB_WIDTH - (visual % TAB_WIDTH);
        } else {
            visual += 1;
        }
    }
    return visual;
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

    const bar = try dye.gray().fmt(" | ", .{});

    var raw_lines: std.ArrayList([]const u8) = .empty;
    defer raw_lines.deinit(allocator);
    var expanded_lines: std.ArrayList([]u8) = .empty;
    defer {
        for (expanded_lines.items) |e| allocator.free(e);
        expanded_lines.deinit(allocator);
    }

    {
        var lines = std.mem.splitScalar(u8, source, '\n');
        var line_number: usize = 1;
        while (lines.next()) |raw_line| : (line_number += 1) {
            if (line_number < span.line_start) continue;
            if (line_number > span.line_end) break;
            try raw_lines.append(allocator, raw_line);
            try expanded_lines.append(allocator, try expandTabs(allocator, raw_line));
        }
    }

    var common_trim: usize = std.math.maxInt(usize);
    for (expanded_lines.items) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) continue;
        const leading = line.len - std.mem.trimStart(u8, line, " ").len;
        common_trim = @min(common_trim, leading);
    }
    if (common_trim == std.math.maxInt(usize)) common_trim = 0;

    try writer.splatByteAll(' ', span_label.width + 2);
    try writer.writeAll(bar);
    try writer.writeByte('\n');

    const larrow = try dye.redBright().fmt(">", .{});
    const rarrow = try dye.redBright().fmt("<", .{});

    for (raw_lines.items, expanded_lines.items, 0..) |raw_line, expanded, i| {
        const line_number = span.line_start + i;

        if (line_number == span.line_start) {
            try writer.print("  {s}{s}", .{ span_label.text, bar });
        } else {
            try writer.splatByteAll(' ', span_label.width + 2);
            try writer.writeAll(bar);
        }

        const left_trim = @min(common_trim, expanded.len);
        const line = std.mem.trimEnd(u8, expanded[left_trim..], " \r");

        if (span.line_start == span.line_end) {
            // single-line span
            const start = @min(visualCol(raw_line, span.column_start - 1) -| left_trim, line.len);
            const end = @min(visualCol(raw_line, span.column_end - 1) -| left_trim, line.len);

            try writer.writeAll(line[0..start]);
            try writer.writeAll(larrow);
            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[start..end]}));
            try writer.writeAll(rarrow);
            try writer.writeAll(line[end..]);
        } else if (line_number == span.line_start) {
            // first line of a multiline span
            const start = @min(visualCol(raw_line, span.column_start - 1) -| left_trim, line.len);

            try writer.writeAll(line[0..start]);
            try writer.writeAll(larrow);
            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[start..]}));
        } else if (line_number == span.line_end) {
            // last line of a multiline span
            const end = @min(visualCol(raw_line, span.column_end - 1) -| left_trim, line.len);

            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[0..end]}));
            try writer.writeAll(rarrow);
            try writer.writeAll(line[end..]);
        } else {
            try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line}));
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
