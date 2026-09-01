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

    pub fn fromTypeExpression(type_expr: TypeExpression) ?SemaType {
        const types: std.StaticStringMap(SemaType) = .initComptime(.{
            .{ "string", .string },
            .{ "char", .char },
            .{ "int", .int },
            .{ "wideint", .wideint },
            .{ "float", .float },
            .{ "double", .double },
            .{ "bool", .bool },
        });

        return types.get(type_expr.identifier);
    }

    pub fn toString(self: SemaType) []const u8 {
        return switch (self) {
            .string => "string",
            .char => "char",
            .int => "int",
            .wideint => "wideint",
            .float => "float",
            .double => "double",
            .bool => "bool",
        };
    }

    pub fn eql(self: SemaType, other: SemaType) bool {
        return std.meta.activeTag(self) == std.meta.activeTag(other);
    }
};

pub const TypeEntry = struct {
    sem_type: SemaType,
    span: Span,
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
