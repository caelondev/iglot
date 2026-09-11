const std = @import("std");
const FaruDiagnostic = @import("../../../diagnostics/diagnostics.zig").FaruDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const FaruSemanticAnalyzer = @import("../sema.zig").FaruSemanticAnalyzer;

pub fn validateBreakStatement(
    sema: *FaruSemanticAnalyzer,
    allocator: std.mem.Allocator,
    l: *const ast.BreakStatement,
) anyerror!?ast.BreakStatement {
    if (!sema.is_in_loop) {
        try sema.reportError(allocator, .{
            .span = l.span,
            .kind = .IllegalBreak,
        });
        return null;
    }

    return .{ .span = l.span };
}
