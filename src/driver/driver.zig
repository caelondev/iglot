const std = @import("std");
const ast = @import("../frontend/parser/ast.zig");

const InkDye = @import("inkdye");
const IglotLexer = @import("../frontend/lexer/lexer.zig").IglotLexer;
const IglotParser = @import("../frontend/parser/parser.zig").IglotParser;
const IglotModule = @import("module.zig").IglotModule;
const IglotDiagnostic = @import("../diagnostics/diagnostics.zig").IglotDiagnostic;

const renderDiagnostics = @import("../diagnostics/render_diagnostics.zig").renderDiagnostics;

pub const IglotModuleDriver = struct {
    next_id: u32,
    diagnostics: std.ArrayList(IglotDiagnostic),
    errors: usize,

    const Self = @This();
    pub fn init() Self {
        return .{
            .next_id = 0,
            .diagnostics = .empty,
            .errors = 0,
        };
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

        return .{ .id = self.next_id, .path = path, .source = source, .program = program };
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
