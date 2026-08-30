const tokens = @import("../lexer/tokens.zig");
const std = @import("std");
const SemaType = @import("../sema/type_table.zig").SemaType;

pub const CiscoDiagnostic = struct {
    span: tokens.Span,
    severity: Severity = .err,
    kind: Kind,
    annotation: ?Annotation = null,

    pub const Severity = enum {
        err,
        warning,
    };

    pub const Kind = union(enum) {
        // Parser
        ParseIntegerOverflow,
        MissingRightHandSideExpression,
        InvalidLeftHandSideDeclaration,
        MissingType,
        ExpectedToken: struct {
            expected: tokens.TokenKind,
            found: tokens.TokenKind,
        },

        // Sema
        InvalidBinaryExpressionType: struct {
            left: SemaType,
            operator: tokens.TokenKind,
            right: SemaType,
        },

        pub fn toMessage(self: Kind, writer: *std.Io.Writer) !void {
            switch (self) {
                .ParseIntegerOverflow => try writer.writeAll("integer literal overflowed while parsing"),
                .MissingRightHandSideExpression => try writer.writeAll("expected an expression after the operator"),
                .InvalidLeftHandSideDeclaration => try writer.writeAll("invalid expression on the left-hand side of a declaration"),
                .MissingType => try writer.writeAll("expected a type in this declaration"),
                .ExpectedToken => |e| try writer.print("expected \"{s}\" found \"{s}\"", .{ @tagName(e.expected), @tagName(e.found) }),

                .InvalidBinaryExpressionType => |e| try writer.print("operator '{s}' cannot be applied to type \"{s}\" and \"{s}\"", .{ @tagName(e.operator), e.left.toString(), e.right.toString() }),
            }
        }
    };

    pub const Annotation = union(enum) {
        note: Note,
        help: Help,
    };

    pub const Note = struct {
        span: ?tokens.Span = null,
        message: []const u8,
    };

    pub const Help = struct {
        message: []const u8,
    };
};
