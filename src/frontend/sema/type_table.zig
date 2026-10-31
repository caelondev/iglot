const std = @import("std");
const Span = @import("../lexer/tokens.zig").Span;
const ast = @import("../parser/ast.zig");
const IglotSemanticAnalyzer = @import("sema.zig").IglotSemanticAnalyzer;

pub const SemaArraySize = union(enum) {
    infer,
    unknown, // const-eval failed, error already reported
    known: u64,
    unbounded, // unsed by builtin functions

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

    function: Function,

    array: Array,

    constant: *SemaType,

    // builtin params only, for now. used in args
    any,

    // poison type for error recovery so `eql`
    // wont report again.
    err,

    // special type used for error messages
    number,

    pub const Function = struct {
        parameters: []*SemaType,
        return_type: *SemaType,
    };

    pub const Array = struct {
        size: SemaArraySize,
        element_type: *SemaType,
    };

    /// strict: rejects array infer anywhere.
    pub fn fromTypeExpression(
        sema: *IglotSemanticAnalyzer,
        allocator: std.mem.Allocator,
        type_expr: ast.TypeExpression,
    ) !?SemaType {
        const t = try resolve(sema, allocator, type_expr) orelse return null;

        if (t.hasInfer()) {
            try sema.reportError(allocator, .{
                .span = type_expr.span,
                .kind = .ArraySizeTypeInfer,
            });
            return null;
        }

        return t;
    }

    /// only for array literal heads, where the outermost `_` is legal.
    pub fn fromTypeExpressionAllowInfer(
        sema: *IglotSemanticAnalyzer,
        allocator: std.mem.Allocator,
        type_expr: ast.TypeExpression,
    ) !?SemaType {
        return resolve(sema, allocator, type_expr);
    }

    /// true if any array size in this type is inferred
    pub fn hasInfer(self: SemaType) bool {
        return switch (self) {
            .array => |a| a.size == .infer or a.element_type.hasInfer(),
            .function => |f| blk: {
                for (f.parameters) |p| {
                    if (p.hasInfer()) break :blk true;
                }
                break :blk f.return_type.hasInfer();
            },
            else => false,
        };
    }

    /// the actual recursion. all nested calls go through `resolve`, never
    /// the strict wrapper, so `[_][2]int` survives until validateArrayExpr.
    fn resolve(
        sema: *IglotSemanticAnalyzer,
        allocator: std.mem.Allocator,
        type_expr: ast.TypeExpression,
    ) anyerror!?SemaType {
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
            .final => |f| try resolve(sema, allocator, f.*),
            .function => |f| blk: {
                var params: std.ArrayList(*SemaType) = .empty;

                for (f.parameters) |te| {
                    const typ = try resolve(sema, allocator, te.*) orelse return null;
                    const typ_ptr = try allocator.create(SemaType);
                    typ_ptr.* = typ;

                    try params.append(allocator, typ_ptr);
                }

                const ret_sema = try resolve(sema, allocator, f.return_type.*) orelse return null;
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
                elem_ptr.* = try resolve(sema, allocator, a.element_type.*) orelse return null;

                break :blk .{ .array = .{ .size = size, .element_type = elem_ptr } };
            },
            .constant => |c| try resolve(sema, allocator, c.*),
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
                    .unbounded => try writer.writeAll("unbounded"),
                }
                try writer.writeAll("]");
                try writeSymbolString(writer, a.element_type.*);
            },
            .constant => |c| {
                try writer.writeAll("const ");
                try writeSymbolString(writer, c.*);
            },
            .any => try writer.writeAll("any"),
            .err => unreachable,
        };
    }

    pub fn eql(self: SemaType, other: SemaType) bool {
        if (self == .err or other == .err) return true;
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;

        return switch (self) {
            .constant => |c| c.eql(other.constant.*),

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

    /// Checks whether `found` satisfies the constraints of `self`:
    /// `expected.accepts(found)`.
    /// `any` accepts any non-void type, including array elements of differing types.
    /// Unbounded arrays accept any length while still validating their element types.
    pub fn accepts(self: SemaType, found: SemaType) bool {
        if (self == .err or found == .err) return true;

        return switch (self) {
            .any => return std.meta.activeTag(found) != .void,
            .array => |a| blk: {
                if (a.size == .unbounded) {
                    break :blk a.element_type.accepts(found);
                }

                break :blk found.eql(self);
            },
            else => found.eql(self),
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
    mutability: ast.TypeExpression.Mutability,
    is_builtin: bool = false,

    /// initializer expression for this symbol. only populated for constant
    /// declarations, since those are the only ones with a compile-time value
    /// evalConstInt can resolve. null for everything else (mutable, final, params, etc).
    init_expr: ?*const ast.Expression = null,
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
