const std = @import("std");
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const inst = @import("instruction.zig");
const typed_ast = @import("../../frontend/sema/typed_ast.zig");
const ast = @import("../../frontend/parser/ast.zig");
const tt = @import("../../frontend/sema/type_table.zig");

pub const FaruIR = struct {
    type_table: tt.TypeTable,
    module: Module,
    current_fn: *Function,
    current_block: *BasicBlock,

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),
            .type_table = undefined,
            .current_fn = undefined,
            .current_block = undefined,
        };
    }

    pub fn buildProgram(self: *Self, allocator: std.mem.Allocator, t_ast: typed_ast.TypedProgram) !void {
        self.type_table = .init(allocator);

        for (t_ast.body) |stmt| {
            self.buildTopLevelStmt(allocator, stmt);
        }
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !void {
        _ = self;
        _ = allocator;
        _ = stmt;
    }
};
