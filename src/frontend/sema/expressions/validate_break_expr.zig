const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateBreakExpression(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    b: *const ast.BreakExpression,
) anyerror!?ast.BreakExpression {
    if (sema.loop_depth == 0) {
        try sema.reportError(allocator, .{
            .span = b.span,
            .kind = .IllegalBreak,
        });
        return null;
    }

    return .{ .span = b.span };
}
