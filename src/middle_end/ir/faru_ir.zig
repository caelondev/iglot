const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const typed_ast = @import("../../frontend/sema/typed_ast.zig");
const ast = @import("../../frontend/parser/ast.zig");
const tt = @import("../../frontend/sema/type_table.zig");

const buildFunctionDecl = @import("statements/function_decl.zig").buildFunctionDecl;
const buildReturnStmt = @import("statements/return.zig").buildReturnStmt;

const lit = @import("expressions/literal.zig");
const buildBinaryExpr = @import("expressions/binary.zig").buildBinaryExpr;

pub const FaruIR = struct {
    type_table: tt.TypeTable,
    module: Module,
    current_fn: *Function,
    current_block: *BasicBlock,

    global_symtab: std.StringHashMapUnmanaged(inst.GlobalRef),

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .type_table = undefined,
            .current_fn = undefined,
            .current_block = undefined,
            .global_symtab = .empty,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.type_table.deinit(allocator);
        self.global_symtab.deinit(allocator);
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, t_ast: typed_ast.TypedProgram) !void {
        self.type_table = try .init(allocator);
        try self.initFaruBuiltins(allocator);

        for (t_ast.body) |stmt| {
            try self.buildTopLevelStmt(allocator, stmt) orelse continue;
        }
    }

    pub fn initFaruBuiltins(self: *Self, allocator: std.mem.Allocator) !void {
        _ = try self.addGlobal(allocator, "true", .bool, .{ .bool = true });
        _ = try self.addGlobal(allocator, "false", .bool, .{ .bool = false });
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .function_decl => |*f| try buildFunctionDecl(self, allocator, f) orelse return null,
            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "illegal top level stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .return_stmt => |*r| try buildReturnStmt(self, allocator, r) orelse return null,

            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "TODO: build stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildExpression(self: *Self, allocator: std.mem.Allocator, expr: *const typed_ast.TypedExpr) anyerror!?inst.VReg {
        const sema_type = expr.sem_type;

        return switch (expr.kind) {
            .integer => |*i| try lit.buildIntegerLit(self, allocator, i, sema_type),
            .wide_integer => |*i| try lit.buildWideIntegerLit(self, allocator, i, sema_type),
            .float => |*f| try lit.buildFloatLit(self, allocator, f, sema_type),
            .string => |*s| try lit.buildStringLit(self, allocator, s, sema_type),
            .identifier => |*i| try self.resolveIdentifier(allocator, i, sema_type),

            .binary => |*b| try buildBinaryExpr(self, allocator, b),

            else => |e| {
                const msg = try std.fmt.allocPrint(allocator, "TODO: build expr {s}", .{@tagName(e)});
                @panic(msg);
            },
        };
    }

    pub fn buildBodyStmt(self: *Self, allocator: std.mem.Allocator, block: typed_ast.TypedBlockStatement) !?void {
        for (block.typed_stmts) |stmt| {
            try self.buildStmt(allocator, stmt) orelse return null;
        }
    }

    pub fn resolveIdentifier(self: *Self, allocator: std.mem.Allocator, i: *const typed_ast.TypedIdentifier, sema_type: tt.SemaType) !?inst.VReg {
        const ref = self.global_symtab.get(i.value) orelse unreachable;
        const dest = self.current_fn.newVReg();

        try self.emit(allocator, .{
            .data = .{ .global = ref },
            .op = .load_global,
            .operands = &.{},
            .sema_type = sema_type,
            .result = dest,
        });
        return dest;
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.instructions.append(allocator, instruction);
    }

    pub fn addGlobal(self: *Self, allocator: std.mem.Allocator, name: []const u8, sema_type: tt.SemaType, initializer: inst.ConstantValue) !inst.GlobalRef {
        const id: u32 = @intCast(self.module.globals.items.len);
        try self.module.globals.append(allocator, .{ .name = name, .sema_type = sema_type, .initializer = initializer });
        const ref = inst.GlobalRef{ .id = id };
        try self.global_symtab.put(allocator, name, ref);
        return ref;
    }

    pub fn goToBlock(self: *Self, block: *BasicBlock) void {
        self.current_block = block;
    }
};
