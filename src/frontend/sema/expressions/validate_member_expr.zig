const std = @import("std");
const IglotDiagnostic = @import("../../../diagnostics/diagnostics.zig").IglotDiagnostic;
const tt = @import("../type_table.zig");
const ast = @import("../../parser/ast.zig");
const typed_ast = @import("../typed_ast.zig");
const Span = @import("../../lexer/tokens.zig").Span;
const IglotSemanticAnalyzer = @import("../sema.zig").IglotSemanticAnalyzer;

pub fn validateMemberExpr(
    sema: *IglotSemanticAnalyzer,
    allocator: std.mem.Allocator,
    m: *const ast.MemberExpression,
    span: Span,
    expected_type: ?tt.SemaType,
) anyerror!?*typed_ast.TypedExpr {
    _ = span; // autofix
    _ = expected_type; // autofix

    const obj = try sema.validateExpression(allocator, m.object, m.object.span, null) orelse return null;
    const struct_type: *tt.SemaType.Struct = switch (obj.sem_type) {
        .@"struct" => |s| s,
        else => {
            try sema.reportError(allocator, .{
                .kind = .{ .NonStructAccess = .{ .sem_type = obj.sem_type } },
                .span = obj.span,
            });
            return null;
        },
    };
    _ = struct_type; // autofix

    return null;
}
