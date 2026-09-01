const std = @import("std");
const CiscoDiagnostic = @import("diagnostics.zig").CiscoDiagnostic;
const Span = @import("../lexer/tokens.zig").Span;
const InkDye = @import("inkdye");

const TAB_WIDTH: usize = 4;

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

// expands tabs to spaces at TAB_WIDTH stops, so our own column math matches
// what actually gets printed instead of trusting the terminal.
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

/// maps a 0-based character offset in `line` (tabs count as 1, matching how
/// the lexer counts columns) to the 0-based visual column after tab expansion.
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

/// the raw + tab-expanded lines covered by a span, plus the shared dedent
/// amount applied to all of them (min leading whitespace across non-blank
/// lines, so relative indentation between lines is preserved).
const SpanLines = struct {
    raw: std.ArrayList([]const u8) = .empty,
    expanded: std.ArrayList([]u8) = .empty,
    common_trim: usize = 0,

    fn collect(allocator: std.mem.Allocator, source: []const u8, span: Span) !SpanLines {
        var self: SpanLines = .{};
        errdefer self.deinit(allocator);

        var lines = std.mem.splitScalar(u8, source, '\n');
        var line_number: usize = 1;
        while (lines.next()) |raw_line| : (line_number += 1) {
            if (line_number < span.line_start) continue;
            if (line_number > span.line_end) break;

            try self.raw.append(allocator, raw_line);
            try self.expanded.append(allocator, try expandTabs(allocator, raw_line));
        }

        self.common_trim = computeCommonTrim(self.expanded.items);
        return self;
    }

    fn deinit(self: *SpanLines, allocator: std.mem.Allocator) void {
        self.raw.deinit(allocator);
        for (self.expanded.items) |line| allocator.free(line);
        self.expanded.deinit(allocator);
    }
};

fn computeCommonTrim(expanded_lines: []const []const u8) usize {
    var common_trim: usize = std.math.maxInt(usize);
    for (expanded_lines) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len == 0) continue; // blank lines don't constrain the dedent
        const leading = line.len - std.mem.trimStart(u8, line, " ").len;
        common_trim = @min(common_trim, leading);
    }
    return if (common_trim == std.math.maxInt(usize)) 0 else common_trim;
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

    var lines = try SpanLines.collect(allocator, source, span);
    defer lines.deinit(allocator);

    const bar = try dye.gray().fmt(" | ", .{});

    try writeGutterBlank(writer, bar, span_label.width);

    for (lines.raw.items, lines.expanded.items, 0..) |raw_line, expanded, i| {
        const line_number = span.line_start + i;
        const is_first = line_number == span.line_start;
        const is_last = line_number == span.line_end;

        if (is_first) {
            try writer.print("  {s}{s}", .{ span_label.text, bar });
        } else {
            try writeGutterPrefix(writer, bar, span_label.width);
        }

        const left_trim = @min(lines.common_trim, expanded.len);
        const line = std.mem.trimEnd(u8, expanded[left_trim..], " \r");

        if (span.line_start == span.line_end) {
            try writeSingleLineSpan(writer, dye, line, raw_line, span, left_trim);
        } else if (is_first) {
            try writeMultilineFirstLine(writer, dye, line, raw_line, span, left_trim);
        } else if (is_last) {
            try writeMultilineLastLine(writer, dye, line, raw_line, span, left_trim);
        } else {
            try writeMultilineMiddleLine(writer, dye, line);
        }

        try writer.writeByte('\n');
    }

    try writeGutterBlank(writer, bar, span_label.width);
}

// prefix only, no trailing newline — used before content on the same line.
fn writeGutterPrefix(writer: *std.Io.Writer, bar: []const u8, label_width: usize) !void {
    try writer.splatByteAll(' ', label_width + 2);
    try writer.writeAll(bar);
}

// a genuinely blank gutter line (used above/below the snippet).
fn writeGutterBlank(writer: *std.Io.Writer, bar: []const u8, label_width: usize) !void {
    try writeGutterPrefix(writer, bar, label_width);
    try writer.writeByte('\n');
}

fn writeSingleLineSpan(
    writer: *std.Io.Writer,
    dye: *InkDye.RuntimeChameleon,
    line: []const u8,
    raw_line: []const u8,
    span: Span,
    left_trim: usize,
) !void {
    const start = @min(visualCol(raw_line, span.column_start - 1) -| left_trim, line.len);
    const end = @min(visualCol(raw_line, span.column_end - 1) -| left_trim, line.len);

    try writer.writeAll(line[0..start]);
    try writer.writeAll(try dye.redBright().fmt(">", .{}));
    try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[start..end]}));
    try writer.writeAll(try dye.redBright().fmt("<", .{}));
    try writer.writeAll(line[end..]);
}

fn writeMultilineFirstLine(
    writer: *std.Io.Writer,
    dye: *InkDye.RuntimeChameleon,
    line: []const u8,
    raw_line: []const u8,
    span: Span,
    left_trim: usize,
) !void {
    const start = @min(visualCol(raw_line, span.column_start - 1) -| left_trim, line.len);

    try writer.writeAll(line[0..start]);
    try writer.writeAll(try dye.redBright().fmt(">", .{}));
    try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[start..]}));
}

fn writeMultilineLastLine(
    writer: *std.Io.Writer,
    dye: *InkDye.RuntimeChameleon,
    line: []const u8,
    raw_line: []const u8,
    span: Span,
    left_trim: usize,
) !void {
    const end = @min(visualCol(raw_line, span.column_end - 1) -| left_trim, line.len);

    try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line[0..end]}));
    try writer.writeAll(try dye.redBright().fmt("<", .{}));
    try writer.writeAll(line[end..]);
}

fn writeMultilineMiddleLine(
    writer: *std.Io.Writer,
    dye: *InkDye.RuntimeChameleon,
    line: []const u8,
) !void {
    try writer.writeAll(try dye.bgRed().bold().fmt("{s}", .{line}));
}

const SpanLabel = struct {
    text: []const u8,
    width: usize,
};

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
