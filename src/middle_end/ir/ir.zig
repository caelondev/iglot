const std = @import("std");
const inst = @import("instruction.zig");
const typed_ast = @import("../../frontend/sema/typed_ast.zig");
const ast = @import("../../frontend/parser/ast.zig");
const tt = @import("../../frontend/sema/type_table.zig");
const builtins = @import("../../vm/builtins.zig");
const IglotModule = @import("../../driver/module.zig").IglotModule;
const Module = @import("module.zig").Module;
const Function = @import("function.zig").Function;
const Params = @import("function.zig").Params;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const ScopeStack = @import("scope_table.zig").ScopeStack;

const simplifyCfg = @import("simplify_cfg.zig").simplifyCfg;

const buildFunctionDecl = @import("statements/function_decl.zig").buildFunctionDecl;
const buildVariableDecl = @import("statements/variable_decl.zig").buildVariableDecl;
const buildLoopStmt = @import("statements/loop.zig").buildLoopStmt;
const buildIfStmt = @import("statements/if_stmt.zig").buildIfStmt;

const lit = @import("expressions/literal.zig");
const buildUnaryExpr = @import("expressions/unary.zig").buildUnaryExpr;
const buildBinaryExpr = @import("expressions/binary.zig").buildBinaryExpr;
const buildAssignmentExpr = @import("expressions/assignment.zig").buildAssignmentExpr;
const buildArrayExpr = @import("expressions/array.zig").buildArrayExpr;
const buildCallExpr = @import("expressions/call.zig").buildCallExpr;
const buildIndexExpr = @import("expressions/index.zig").buildIndexExpr;
const buildStructInitExpr = @import("expressions/struct_init.zig").buildStructInitExpr;
const buildMemberExpr = @import("expressions/member.zig").buildMemberExpr;
const buildNullUnwrapExpr = @import("expressions/null_unwrap.zig").buildNullUnwrapExpr;
const buildBreakExpr = @import("expressions/break.zig").buildBreakExpr;
const buildReturnExpr = @import("expressions/return.zig").buildReturnExpr;

const IdentKind = @import("expressions/call.zig").IdentKind;
const ResolvedIdent = @import("expressions/call.zig").ResolvedIdent;
const LoopContext = struct {
    break_block: inst.BlockRef,
};

pub const IglotIR = struct {
    module: Module,

    current_fn: *Function,
    current_block: *BasicBlock,
    current_scope: *ScopeStack,
    loop_stack: std.ArrayList(LoopContext),

    global_symtab: std.StringHashMapUnmanaged(inst.GlobalRef),
    struct_ids: std.StringHashMapUnmanaged(u32),
    current_module: u32,
    entry_module: u32,

    const Self = @This();
    pub fn init() Self {
        return .{
            .module = .init(),

            .current_scope = undefined,
            .current_fn = undefined,
            .current_block = undefined,
            .loop_stack = .empty,

            .global_symtab = .empty,
            .struct_ids = .empty,
            .current_module = 0,
            .entry_module = 0,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.global_symtab.deinit(allocator);
        self.loop_stack.deinit(allocator);
        self.current_scope.deinit(allocator);
    }

    pub fn buildModules(self: *Self, allocator: std.mem.Allocator, programs: []typed_ast.TypedProgram) !?*Module {
        // the entry module is always last
        const entry = programs[programs.len - 1].module_id;
        self.entry_module = entry;

        const init_fn = try self.module.createFunction(allocator, "@$__global_init", &.{}, .void);
        const entry_bb = try init_fn.newBlock(allocator, "entry");

        self.current_fn = init_fn;
        self.goToBlock(entry_bb);
        try self.initIglotBuiltins(allocator);

        for (programs) |prog| {
            self.current_module = prog.module_id;

            const scope_stack = try allocator.create(ScopeStack);
            scope_stack.* = .init();

            self.current_scope = scope_stack;

            for (prog.body) |stmt| {
                try self.hoistDeclaration(allocator, stmt) orelse continue;
            }

            for (prog.body) |stmt| {
                self.current_fn = init_fn;
                self.goToBlock(entry_bb);
                try self.buildTopLevelStmt(allocator, stmt) orelse return null;
            }
        }

        self.current_fn = init_fn;
        self.goToBlock(entry_bb);

        // terminate @$__global_init only after all top-level stmts
        // (including global var initializers) have been emitted
        try self.emit(allocator, .{
            .op = .ret_void,
            .operands = &.{},
            .result = null,
            .data = .none,
            .sema_type = .void,
        });

        const module = try allocator.create(Module);
        module.* = self.module;

        try simplifyCfg(allocator, module);

        return module;
    }

    fn hoistDeclaration(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .function_decl => |*f| {
                var params: std.ArrayList(Params) = .empty;

                for (f.parameters, 0..) |p, i| {
                    try params.append(allocator, .{
                        .name = p.identifier.value,
                        .sema_type = p.param_type,
                        .index = @intCast(i),
                    });
                }

                _ = try self.module.createFunction(
                    allocator,
                    try self.symbolName(allocator, self.current_module, f.identifier.value),
                    try params.toOwnedSlice(allocator),
                    f.return_type,
                );
            },
            else => return null,
        }
    }

    pub fn initIglotBuiltins(self: *Self, allocator: std.mem.Allocator) !void {
        try self.buildBuiltinGlobal(allocator, "true", .bool, .{ .op = .const_bool, .const_data = .{ .bool = true } });
        try self.buildBuiltinGlobal(allocator, "false", .bool, .{ .op = .const_bool, .const_data = .{ .bool = false } });
        try self.buildBuiltinGlobal(allocator, "null", .null, .{ .op = .const_bool, .const_data = .null });
    }

    fn buildBuiltinGlobal(self: *Self, allocator: std.mem.Allocator, global_name: []const u8, sema_type: tt.SemaType, lit_instr: struct { op: inst.Opcode, const_data: inst.ConstantValue }) !void {
        const ref = try self.addGlobal(allocator, global_name, sema_type);
        const dest = self.current_fn.newVReg();
        try self.emit(allocator, .{
            .op = lit_instr.op,
            .data = .{ .constant = lit_instr.const_data },
            .operands = &.{},
            .sema_type = sema_type,
            .result = dest,
        });
        try self.emit(allocator, .{
            .op = .store_global,
            .data = .{ .global = ref },
            .operands = try allocator.dupe(inst.VReg, &.{dest}),
            .sema_type = sema_type,
            .result = null,
        });
    }

    pub fn buildTopLevelStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) !?void {
        switch (stmt) {
            .function_decl => |*f| try buildFunctionDecl(self, allocator, f) orelse return null,
            .struct_decl => {},
            .variable_declaration => |*v| {
                const name = try self.symbolName(allocator, self.current_module, v.identifier.value);
                const ref = try self.addGlobal(allocator, name, v.sema_type);

                const value_reg = try self.buildExpression(allocator, &v.value.*) orelse unreachable;
                try self.emit(allocator, .{
                    .op = .store_global,
                    .data = .{ .global = ref },
                    .operands = try allocator.dupe(inst.VReg, &.{value_reg}),
                    .sema_type = v.sema_type,
                    .result = null,
                });
            },

            else => |s| {
                const msg = try std.fmt.allocPrint(allocator, "illegal top level stmt {s}", .{@tagName(s)});
                @panic(msg);
            },
        }
    }

    pub fn buildStmt(self: *Self, allocator: std.mem.Allocator, stmt: typed_ast.TypedStmt) anyerror!void {
        switch (stmt) {
            .expression => |*e| _ = try self.buildExpression(allocator, e.typed),
            .variable_declaration => |*v| try buildVariableDecl(self, allocator, v),
            .loop => |*l| try buildLoopStmt(self, allocator, l),
            .if_stmt => |*i| try buildIfStmt(self, allocator, i),

            .scoped => |s| try self.buildScopedStmt(allocator, s),
            .block => |b| try self.buildBodyStmt(allocator, b),

            .struct_decl => {},
            .function_decl => unreachable,
        }
    }

    pub fn buildExpression(self: *Self, allocator: std.mem.Allocator, expr: *const typed_ast.TypedExpr) anyerror!?inst.VReg {
        const sema_type = expr.sem_type;

        return switch (expr.kind) {
            .integer => |*i| try lit.buildIntegerLit(self, allocator, i, sema_type),
            .wide_integer => |*i| try lit.buildWideIntegerLit(self, allocator, i, sema_type),
            .float => |*f| try lit.buildFloatLit(self, allocator, f, sema_type),
            .string => |*s| try lit.buildStringLit(self, allocator, s, sema_type),
            .assignment => |*a| try buildAssignmentExpr(self, allocator, a),
            .identifier => |*i| (try self.resolveIdentifier(allocator, i, sema_type)).reg,

            .unary => |*u| try buildUnaryExpr(self, allocator, u),
            .binary => |*b| try buildBinaryExpr(self, allocator, b),

            .call => |*c| try buildCallExpr(self, allocator, c),
            .array => |*a| try buildArrayExpr(self, allocator, a),
            .index => |*i| try buildIndexExpr(self, allocator, i),

            .struct_init => |*s| try buildStructInitExpr(self, allocator, s, sema_type),
            .member => |*m| try buildMemberExpr(self, allocator, m),
            .null_unwrap => |*n| try buildNullUnwrapExpr(self, allocator, n),
            .module_ref => |*mr| (try self.resolveModuleRef(allocator, mr, sema_type)).reg,
            .break_expr => |*b| try buildBreakExpr(self, allocator, b) orelse return null,
            .return_expr => |*r| try buildReturnExpr(self, allocator, r),
        };
    }

    pub fn buildBodyStmt(self: *Self, allocator: std.mem.Allocator, block: typed_ast.TypedBlockStatement) !void {
        for (block.typed_stmts) |stmt| {
            try self.buildStmt(allocator, stmt);
        }
    }
    pub fn buildScopedStmt(self: *Self, allocator: std.mem.Allocator, block: typed_ast.TypedScopedStatement) !void {
        for (block.typed_stmts) |stmt| {
            try self.buildStmt(allocator, stmt);
        }
    }

    pub fn resolveIdentifier(self: *Self, allocator: std.mem.Allocator, i: *const typed_ast.TypedIdentifier, sema_type: tt.SemaType) !ResolvedIdent {
        if (self.current_scope.resolve(i.value)) |reg| {
            return .{ .reg = reg, .kind = .local };
        }

        if (self.global_symtab.contains(i.value)) {
            return self.loadSymbol(allocator, i.value, sema_type);
        }

        const symbol = try self.symbolName(allocator, self.current_module, i.value);
        return self.loadSymbol(allocator, symbol, sema_type);
    }

    fn resolveModuleRef(self: *Self, allocator: std.mem.Allocator, ref: *const typed_ast.TypedModuleRef, sema_type: tt.SemaType) !ResolvedIdent {
        const symbol = try self.symbolName(allocator, ref.module_id, ref.name);
        return try self.loadSymbol(allocator, symbol, sema_type);
    }

    fn loadSymbol(self: *Self, allocator: std.mem.Allocator, symbol: []const u8, sema_type: tt.SemaType) !ResolvedIdent {
        if (self.global_symtab.get(symbol)) |ref| {
            const dest = self.current_fn.newVReg();
            try self.emit(allocator, .{
                .data = .{ .global = ref },
                .op = .load_global,
                .operands = &.{},
                .sema_type = sema_type,
                .result = dest,
            });
            return .{ .reg = dest, .kind = .global };
        }

        const func = self.module.getFunctionByName(symbol) orelse unreachable;
        const dest = self.current_fn.newVReg();
        try self.emit(allocator, .{
            .data = .{ .constant = .{ .func = func.function_ref } },
            .op = .load_fn,
            .operands = &.{},
            .sema_type = sema_type,
            .result = dest,
        });
        return .{ .reg = dest, .kind = .func };
    }

    pub fn emit(self: *Self, allocator: std.mem.Allocator, instruction: inst.Instruction) !void {
        try self.current_block.instructions.append(allocator, instruction);
    }

    pub fn addGlobal(self: *Self, allocator: std.mem.Allocator, global_name: []const u8, sema_type: tt.SemaType) !inst.GlobalRef {
        const id: u32 = @intCast(self.module.globals.items.len);
        try self.module.globals.append(allocator, .{ .name = global_name, .sema_type = sema_type });
        const ref = inst.GlobalRef{ .id = id };
        try self.global_symtab.put(allocator, global_name, ref);
        return ref;
    }

    /// descriptor id for a struct type, created on first use. keyed by name,
    /// same as SemaType.eql. the descriptor holds the field names so debug
    /// output and runtime printing can show them.
    pub fn internStruct(self: *Self, allocator: std.mem.Allocator, s: *tt.SemaType.Struct) !u32 {
        if (self.struct_ids.get(s.name)) |id| return id;

        const id: u32 = @intCast(self.module.struct_descs.items.len);
        const names = try allocator.alloc([]const u8, s.fields.len);
        for (s.fields, names) |f, *n| n.* = f.name;

        try self.module.struct_descs.append(allocator, .{ .name = s.name, .field_names = names });
        try self.struct_ids.put(allocator, s.name, id);
        return id;
    }

    pub fn goToBlock(self: *Self, block: *BasicBlock) void {
        self.current_block = block;
    }

    pub fn pushLoopContext(self: *Self, allocator: std.mem.Allocator, ctx: LoopContext) !void {
        try self.loop_stack.append(allocator, ctx);
    }

    pub fn popLoopContext(self: *Self) void {
        _ = self.loop_stack.pop();
    }

    pub fn symbolName(self: *Self, allocator: std.mem.Allocator, id: u32, name: []const u8) ![]const u8 {
        if (self.entry_module == id and std.mem.eql(u8, name, "main")) return name;
        const mangled = try allocator.print("iglot_m{d}__{s}", .{ id, name });
        return mangled;
    }
};
