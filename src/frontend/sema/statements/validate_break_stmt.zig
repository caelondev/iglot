const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateBreakStatement(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    l: *const ast.BreakStatement,
) anyerror!?ast.BreakStatement {
    if (sema.loop_depth == 0) {
        try sema.reportError(allocator, .{
            .span = l.span,
            .kind = .IllegalBreak,
        });
        return null;
    }

    return .{ .span = l.span };
}
