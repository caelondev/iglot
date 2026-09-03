const tokens = @import("../lexer/tokens.zig");
const std = @import("std");
const SemaType = @import("../sema/type_table.zig").SemaType;

pub const CiscoDiagnostic = struct {
    span: tokens.Span,
    severity: Severity = .err,
    kind: Kind,
    annotations: []const Annotation = &.{},

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
        InvalidLeftHandSideAssignment,
        InvalidBinaryExpressionType: struct {
            left: SemaType,
            operator: tokens.TokenKind,
            right: SemaType,
        },
        ImpossibleComparison: struct {
            left: SemaType,
            operator: tokens.TokenKind,
            right: SemaType,
        },
        IdentifierAlreadyExist: struct {
            identifier: []const u8,
        },
        TypeMismatch: struct {
            expected: SemaType,
            found: SemaType,
        },
        UndefinedIdentifier: struct { identifier: []const u8 },

        pub fn toMessage(self: Kind, writer: *std.Io.Writer) !void {
            switch (self) {
                .ParseIntegerOverflow => try writer.writeAll("integer literal overflowed while parsing"),
                .MissingRightHandSideExpression => try writer.writeAll("expected an expression after the operator"),
                .InvalidLeftHandSideDeclaration => try writer.writeAll("invalid expression on the left-hand side of a declaration"),
                .MissingType => try writer.writeAll("expected a type in this declaration"),
                .ExpectedToken => |e| try writer.print("expected \"{s}\" found \"{s}\"", .{ @tagName(e.expected), @tagName(e.found) }),

                .InvalidBinaryExpressionType => |e| try writer.print("operator '{s}' cannot be applied to type \"{s}\" and \"{s}\"", .{ @tagName(e.operator), e.left.toString(), e.right.toString() }),
                .IdentifierAlreadyExist => |e| try writer.print("cannot redeclare identifier \"{s}\"", .{e.identifier}),
                .TypeMismatch => |e| try writer.print("expected type \"{s}\", found type \"{s}\"", .{ e.expected.toString(), e.found.toString() }),
                .ImpossibleComparison => |e| try writer.print("cannot perform comparison \"{s}\" to type \"{s}\" and \"{s}\"", .{ @tagName(e.operator), e.left.toString(), e.right.toString() }),
                .InvalidLeftHandSideAssignment => try writer.print("cannot assign to this expression", .{}),
                .UndefinedIdentifier => |i| try writer.print("cannot resolve identifier \"{s}\"", .{i.identifier}),
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
