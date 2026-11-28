const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateContinueExpression(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    c: *const ast.ContinueExpression,
) anyerror!?ast.ContinueExpression {
    if (sema.loop_depth == 0) {
        try sema.reportError(allocator, .{
            .span = c.span,
            .kind = .IllegalContinue,
        });
        return null;
    }

    return .{ .span = c.span };
}
