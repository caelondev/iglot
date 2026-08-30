pub const TypeExpression = @import("../parser/ast.zig").TypeExpression;
const std = @import("std");

pub const SemaType = union(enum) {
    string,
    char,
    int, // i64
    wideint, // i128
    float,
    double,

    pub fn fromTypeExpression(type_expr: TypeExpression) ?SemaType {
        const types: std.StaticStringMap(SemaType) = .initComptime(.{
            .{ "string", .string },
            .{ "char", .char },
            .{ "int", .int },
            .{ "wideint", .wideint },
            .{ "float", .float },
            .{ "double", .double },
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
        };
    }

    pub fn eql(self: SemaType, other: SemaType) bool {
        return std.meta.activeTag(self) == std.meta.activeTag(other);
    }
};

pub const TypeEntry = struct {
    sem_type: SemaType,
    name: []const u8,
};

pub const TypeTable = struct {
    types: std.StringHashMapUnmanaged(TypeEntry),
};
