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

    function: struct {
        parameters: []*SemaType,
        return_type: *SemaType,
    },

    // special type used for error messages
    number,

    pub fn fromTypeExpression(
        allocator: std.mem.Allocator,
        type_expr: TypeExpression,
    ) !?SemaType {
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
            .final => |f| try fromTypeExpression(allocator, f.*),
            .function => |f| blk: {
                var params: std.ArrayList(*SemaType) = .empty;

                for (f.parameters) |te| {
                    const sema = try fromTypeExpression(allocator, te.*) orelse return null;
                    const sema_ptr = try allocator.create(SemaType);
                    sema_ptr.* = sema;

                    try params.append(allocator, sema_ptr);
                }

                const ret_sema = try fromTypeExpression(allocator, f.return_type.*) orelse return null;
                const ret_ptr = try allocator.create(SemaType);
                ret_ptr.* = ret_sema;

                break :blk .{
                    .function = .{
                        .parameters = try params.toOwnedSlice(allocator),
                        .return_type = ret_ptr,
                    },
                };
            },
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
            .function => |f| {
                try writer.writeAll("fn (");

                for (f.parameters, 0..) |p, i| {
                    try writeSymbolString(writer, p.*);

                    if (f.parameters.len != i + 1)
                        try writer.writeAll(", ");
                }

                try writer.writeAll(") ");
                try writeSymbolString(writer, f.return_type.*);
            },
        };
    }

    pub fn eql(self: SemaType, other: SemaType) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;

        return switch (self) {
            .function => |sf| blk: {
                const of = other.function;

                if (sf.parameters.len != of.parameters.len) break :blk false;

                for (sf.parameters, of.parameters) |sp, op| {
                    if (!sp.eql(op.*)) break :blk false;
                }

                break :blk sf.return_type.eql(of.return_type.*);
            },

            else => true,
        };
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
