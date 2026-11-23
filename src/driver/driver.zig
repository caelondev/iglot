const std = @import("std");
const ast = @import("../frontend/parser/ast.zig");

const InkDye = @import("inkdye");
const IglotLexer = @import("../frontend/lexer/lexer.zig").IglotLexer;
const IglotParser = @import("../frontend/parser/parser.zig").IglotParser;
const IglotModule = @import("module.zig").IglotModule;
const IglotDiagnostic = @import("../diagnostics/diagnostics.zig").IglotDiagnostic;
const pathExists = @import("../cli/helpers/path_exists.zig").pathExists;

const renderDiagnostics = @import("../diagnostics/render_diagnostics.zig").renderDiagnostics;

pub const IglotModuleDriver = struct {
    next_id: u32,
    diagnostics: std.ArrayList(IglotDiagnostic),
    errors: usize,
    modules: std.StringHashMapUnmanaged(*IglotModule),
    in_progress: std.StringHashMapUnmanaged(void), // paths being loaded (cycle detection)
    order: std.ArrayList(*IglotModule),
    stack: std.ArrayList(*IglotModule), // modules currently being loaded, in import order

    const Self = @This();
    pub fn init() Self {
        return .{
            .next_id = 0,
            .errors = 0,
            .diagnostics = .empty,
            .modules = .empty,
            .in_progress = .empty,
            .order = .empty,
            .stack = .empty,
        };
    }

    pub fn loadProgram(
        self: *Self,
        allocator: std.mem.Allocator,
        io: std.Io,
        writer: *std.Io.Writer,
        ewriter: *std.Io.Writer,
        dye: *InkDye.RuntimeChameleon,
        entry: []const u8,
    ) !?[]*IglotModule {
        const entry_path = try std.fs.path.resolve(allocator, &.{entry});
        _ = try self.visit(allocator, io, writer, ewriter, dye, entry_path) orelse return null;
        return self.order.items;
    }

    fn visit(
        self: *Self,
        allocator: std.mem.Allocator,
        io: std.Io,
        writer: *std.Io.Writer,
        ewriter: *std.Io.Writer,
        dye: *InkDye.RuntimeChameleon,
        path: []const u8,
    ) !?*IglotModule {
        if (self.modules.get(path)) |m| return m;

        const mod = try allocator.create(IglotModule);
        mod.* = try self.loadModule(allocator, io, writer, ewriter, dye, path) orelse return null;
        try self.modules.put(allocator, path, mod);
        try self.in_progress.put(allocator, path, {});
        try self.stack.append(allocator, mod);

        for (mod.program.imports) |imp| {
            const dir = std.fs.path.dirname(path) orelse ".";
            const file = try std.fmt.allocPrint(allocator, "{s}.iglot", .{imp.name});
            const dep_path = try std.fs.path.resolve(allocator, &.{ dir, file });

            if (!try pathExists(io, dep_path)) {
                try self.fail(allocator, writer, dye, mod.source, .{
                    .kind = .{ .ModuleNotFound = .{ .name = imp.name } },
                    .span = imp.span,
                });
                return null;
            }
            if (self.in_progress.contains(dep_path)) {
                const chain = try self.cycleChain(allocator, dep_path, imp.name);
                const msg = try std.fmt.allocPrint(allocator, "import chain: {s}", .{chain});

                const notes = try allocator.dupe(IglotDiagnostic.Annotation, &.{.{ .note = .{ .message = msg } }});

                try self.fail(allocator, writer, dye, mod.source, .{
                    .kind = .{ .ImportCycle = .{ .name = imp.name } },
                    .span = imp.span,
                    .annotations = notes,
                });
                return null;
            }
            _ = try self.visit(allocator, io, writer, ewriter, dye, dep_path) orelse return null;
        }

        _ = self.stack.pop();
        _ = self.in_progress.remove(path);
        try self.order.append(allocator, mod);
        return mod;
    }

    pub fn loadModule(self: *Self, allocator: std.mem.Allocator, io: std.Io, writer: *std.Io.Writer, ewriter: *std.Io.Writer, dye: *InkDye.RuntimeChameleon, path: []const u8) !?IglotModule {
        if (!std.mem.eql(u8, std.fs.path.extension(path), ".iglot")) {
            try ewriter.print("{s}: expected a .iglot file\n", .{
                try dye.red().bold().fmt("error", .{}),
            });
            return null;
        }

        const cwd = std.Io.Dir.cwd();
        const source = try cwd.readFileAlloc(
            io,
            path,
            allocator,
            .unlimited,
        );

        var lexer = IglotLexer.init(source);
        var parser = try IglotParser.init(allocator, &lexer);

        const program = try parser.parseProgram(allocator) orelse {
            // it is certain that if parseProgram returned null. module name
            // declaration failed. emitting an error
            try renderParserDiagnostics(
                writer,
                allocator,
                dye,
                source,
                &parser,
            );

            return null;
        };

        if (parser.errors > 0) {
            try renderParserDiagnostics(writer, allocator, dye, source, &parser);
            return null;
        }

        const stem = std.fs.path.stem(path);
        if (!std.mem.eql(u8, program.module_header.name, stem)) {
            try self.reportError(allocator, .{
                .kind = .{
                    .ModuleNameMismatch = .{
                        .found = program.module_header.name,
                        .file_name = stem,
                    },
                },
                .span = program.module_header.span,
            });

            try self.renderPending(writer, allocator, dye, source);
            return null;
        }

        const id = self.next_id;
        self.next_id += 1;
        return .{ .id = id, .path = path, .source = source, .program = program };
    }

    fn cycleChain(self: *Self, allocator: std.mem.Allocator, dep_path: []const u8, closing_name: []const u8) ![]const u8 {
        var buf: std.ArrayList(u8) = .empty;
        var started = false;
        for (self.stack.items) |m| {
            if (std.mem.eql(u8, m.path, dep_path)) started = true;
            if (started) {
                try buf.appendSlice(allocator, m.program.module_header.name);
                try buf.appendSlice(allocator, " -> ");
            }
        }
        try buf.appendSlice(allocator, closing_name);
        return buf.items;
    }

    fn fail(self: *Self, allocator: std.mem.Allocator, writer: *std.Io.Writer, dye: *InkDye.RuntimeChameleon, source: []const u8, diagnostic: IglotDiagnostic) !void {
        self.errors += 1;
        try renderDiagnostics(writer, allocator, dye, source, diagnostic);
        try writer.writeByte('\n');
    }

    fn reportError(self: *Self, allocator: std.mem.Allocator, diagnostic: IglotDiagnostic) !void {
        if (diagnostic.severity == .err) self.errors += 1;
        try self.diagnostics.append(allocator, diagnostic);
    }

    pub fn renderPending(
        self: *const Self,
        writer: *std.Io.Writer,
        allocator: std.mem.Allocator,
        dye: *InkDye.RuntimeChameleon,
        source: []const u8,
    ) !void {
        for (self.diagnostics.items) |diagnostic| {
            try renderDiagnostics(writer, allocator, dye, source, diagnostic);
            try writer.writeByte('\n');
        }
        if (self.errors == 0) return;
        try writer.writeAll(try dye.cyan().fmt("--> ", .{}));
        try writer.print("found {s}\n", .{
            try dye.red().fmt("{d} error(s)", .{self.errors}),
        });
    }
};

fn renderParserDiagnostics(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    dye: *InkDye.RuntimeChameleon,
    source: []const u8,
    parser: *const IglotParser,
) !void {
    for (parser.diagnostics.items) |diagnostic| {
        try renderDiagnostics(
            writer,
            allocator,
            dye,
            source,
            diagnostic,
        );

        try writer.writeByte('\n');
    }
    if (parser.errors == 0) return;
    try writer.writeAll(try dye.cyan().fmt("--> ", .{}));
    try writer.print("found {s}\n", .{
        try dye.red().fmt("{d} error(s)", .{
            parser.errors,
        }),
    });
}
