const std = @import("std");
const Span = @import("../lexer/tokens.zig").Span;
const TypeExpression = @import("../parser/ast.zig").TypeExpression;

pub const SemaType = union(enum) {
    string,
    char,
    int, // i64
    wideint, // i128
    float,
    bool,
    double,
    void,

    // special type used for error messages
    number,

    pub fn fromTypeExpression(
        type_expr: TypeExpression,
    ) ?SemaType {
        const types: std.StaticStringMap(SemaType) = .initComptime(.{
            .{ "string", .string },
            .{ "char", .char },
            .{ "int", .int },
            .{ "wideint", .wideint },
            .{ "float", .float },
            .{ "double", .double },
            .{ "bool", .bool },
            .{ "void", .void },
        });

        return switch (type_expr.kind) {
            .identifier => |i| types.get(i),
            .final => |f| fromTypeExpression(f.*),
        };
    }

    pub fn format(self: SemaType, writer: *std.Io.Writer) !void {
        try writeSymbolString(writer, self);
    }

    pub fn writeSymbolString(writer: *std.Io.Writer, symbol: SemaType) !void {
        try switch (symbol) {
            .string => writer.print("string", .{}),
            .char => writer.print("char", .{}),
            .int => writer.print("int", .{}),
            .wideint => writer.print("wideint", .{}),
            .float => writer.print("float", .{}),
            .double => writer.print("double", .{}),
            .bool => writer.print("bool", .{}),
            .number => writer.print("number", .{}),
            .void => writer.print("void", .{}),
        };
    }

    pub fn eql(self: SemaType, other: SemaType) bool {
        return std.meta.activeTag(self) == std.meta.activeTag(other);
    }

    pub fn is_numerical(self: SemaType) bool {
        return switch (self) {
            .int, .wideint, .float, .double => true,
            else => false,
        };
    }
};

pub const TypeEntry = struct {
    sem_type: SemaType,
    span: Span,
    is_final: bool,
};

pub const TypeTable = struct {
    types: std.StringHashMapUnmanaged(TypeEntry),

    const Self = @This();
    pub fn init() Self {
        return Self{
            .types = .empty,
        };
    }

    pub fn declareIdentifier(self: *Self, allocator: std.mem.Allocator, identifier: []const u8, entry: TypeEntry) !void {
        try self.types.put(allocator, identifier, entry);
    }

    pub fn lookupIdentifier(self: *Self, identifier: []const u8) ?TypeEntry {
        return self.types.get(identifier);
    }
};
