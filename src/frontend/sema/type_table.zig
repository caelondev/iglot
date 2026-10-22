const std = @import("std");
const Span = @import("../lexer/tokens.zig").Span;
const TypeExpression = @import("../parser/ast.zig").TypeExpression;
const IglotSemanticAnalyzer = @import("sema.zig").IglotSemanticAnalyzer;

pub const SemaArraySize = union(enum) {
    infer,
    unknown, // const-eval failed, error already reported
    known: u64,

    pub fn compatible(a: SemaArraySize, b: SemaArraySize) bool {
        return switch (a) {
            .known => |x| switch (b) {
                .known => |y| x == y,
                else => true,
            },
            else => true,
        };
    }
};

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

    array: struct {
        size: SemaArraySize,
        element_type: *SemaType,
    },

    // special type used for error messages
    number,

    // builtin params only, for now. used in args
    any,

    pub fn fromTypeExpression(
        sema: *IglotSemanticAnalyzer,
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
            .final => |f| try fromTypeExpression(sema, allocator, f.*),
            .function => |f| blk: {
                var params: std.ArrayList(*SemaType) = .empty;

                for (f.parameters) |te| {
                    const typ = try fromTypeExpression(sema, allocator, te.*) orelse return null;
                    const typ_ptr = try allocator.create(SemaType);
                    typ_ptr.* = typ;

                    try params.append(allocator, typ_ptr);
                }

                const ret_sema = try fromTypeExpression(sema, allocator, f.return_type.*) orelse return null;
                const ret_ptr = try allocator.create(SemaType);
                ret_ptr.* = ret_sema;

                break :blk .{
                    .function = .{
                        .parameters = try params.toOwnedSlice(allocator),
                        .return_type = ret_ptr,
                    },
                };
            },
            .array => |a| blk: {
                const size: SemaArraySize = switch (a.size) {
                    .infer => .infer,
                    .expr => |e| try sema.resolveArraySize(allocator, e, type_expr.span),
                };

                const elem_ptr = try allocator.create(SemaType);
                elem_ptr.* = try fromTypeExpression(sema, allocator, a.element_type.*) orelse return null;

                break :blk .{ .array = .{ .size = size, .element_type = elem_ptr } };
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
            .array => |a| {
                try writer.writeAll("[");
                switch (a.size) {
                    .infer, .unknown => try writer.writeAll("_"),
                    .known => |n| try writer.print("{d}", .{n}),
                }
                try writer.writeAll("]");
                try writeSymbolString(writer, a.element_type.*);
            },
            .any => try writer.writeAll("any"),
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

            .array => |sa| blk: {
                const oa = other.array;
                if (!sa.element_type.eql(oa.element_type.*)) break :blk false;
                break :blk sa.size.compatible(oa.size);
            },
            else => true,
        };
    }

    /// one-way check for args meeting params: `expected.accepts(found)`.
    /// `any` only works on the expected side and still rejects void
    pub fn accepts(self: SemaType, found: SemaType) bool {
        if (std.meta.activeTag(self) == .any) return std.meta.activeTag(found) != .void;
        return found.eql(self);
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
    is_builtin: bool = false,
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
