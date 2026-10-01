const std = @import("std");
const FaruDiagnostic = @import("../../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateLoopStatement(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    l: *const ast.LoopStatement,
) anyerror!?typed_ast.TypedLoopStatement {
    sema.loop_depth += 1;
    defer sema.loop_depth -= 1;
    const stmt = try sema.validateScopedStatement(allocator, &l.body) orelse return null;
    return .{ .body = stmt };
}
