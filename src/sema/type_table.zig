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
    is_function: bool = false,
};

pub const TypeTable = struct {
    scopes: std.ArrayList(SymbolTable),

    const SymbolTable = std.StringHashMapUnmanaged(TypeEntry);

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .scopes = .empty,
        };
        try self.enterScope(allocator);
        return self;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.scopes.items) |*scope| {
            scope.deinit(allocator);
        }
        self.scopes.deinit(allocator);
    }

    pub fn enterScope(self: *Self, allocator: std.mem.Allocator) !void {
        try self.scopes.append(allocator, .empty);
    }

    pub fn leaveScope(self: *Self, allocator: std.mem.Allocator) void {
        var scope = self.scopes.pop() orelse unreachable;
        scope.deinit(allocator);
    }

    pub fn declareIdentifier(self: *Self, allocator: std.mem.Allocator, identifier: []const u8, entry: TypeEntry) !void {
        const current = &self.scopes.items[self.scopes.items.len - 1];
        try current.put(allocator, identifier, entry);
    }

    pub fn lookupCurrentScope(self: *Self, identifier: []const u8) ?TypeEntry {
        const cur = self.scopes.items[self.scopes.items.len - 1];
        return cur.get(identifier);
    }

    pub fn lookupIdentifier(self: *Self, identifier: []const u8) ?TypeEntry {
        var i = self.scopes.items.len;
        while (i > 0) {
            i -= 1;
            if (self.scopes.items[i].get(identifier)) |entry| {
                return entry;
            }
        }
        return null;
    }
};
