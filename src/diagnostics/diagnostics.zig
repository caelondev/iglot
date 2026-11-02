const tokens = @import("../frontend/lexer/tokens.zig");
const std = @import("std");
const SemaType = @import("../frontend/sema/type_table.zig").SemaType;

pub const IglotDiagnostic = struct {
    span: tokens.Span,
    severity: Severity = .err,
    kind: Kind,
    annotations: []const Annotation = &.{},

    pub const Severity = enum {
        err,
        warning,
    };

    pub const Indexable = enum { fixed_array };

    pub const Kind = union(enum) {
        // Parser
        ParseIntegerOverflow,
        MissingRightHandSideExpression,
        InvalidLeftHandSideDeclaration,
        MissingType,
        RedundantFinal,
        RedundantConst,
        ExpectedToken: struct {
            expected: tokens.TokenKind,
            found: tokens.TokenKind,
        },
        UnexpectedToken: struct {
            found: tokens.TokenKind,
        },
        UnexpectedTokenInType: struct {
            found: tokens.TokenKind,
        },
        ArraySizeTypeInfer,
        IllegalArraySizeExpression,

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
        ReturnTypeMismatch: struct {
            expected: SemaType,
            found: SemaType,
        },
        UndefinedIdentifier: struct { identifier: []const u8 },
        UndefinedType: struct { identifier: []const u8 },
        FinalIdentifierAssignment: struct { identifier: []const u8 },
        ConstIdentifierAssignment: struct { identifier: []const u8 },
        ConstIdentifierMutation: struct { identifier: []const u8 },
        FunctionAssignment: struct { identifier: []const u8 },
        StructAssignment: struct { identifier: []const u8 },
        VoidValueStorage: struct { identifier: []const u8 },
        MissingReturn: struct { name: []const u8 },
        IntegerOverflow,
        IllegalReturn,
        IllegalTopLevelStatement,
        IllegalBreak,
        NestedFunctionDeclaration,
        NonCallableCallee: struct { callee_type: SemaType },
        TooFewArguments: struct { expected: usize, found: usize },
        TooManyArguments: struct { expected: usize, found: usize },
        NonVoidMainReturnType: struct { found: SemaType },
        ArraySizeNotConstant,
        InvalidArraySize: struct { value: i128 },
        ArraySizeMismatch: struct { expected: u64, found: u64 },
        ArraySizeTooLarge: struct { found: i128, max: u64 },
        CannotInferLiteralType,
        InvalidIndexOperand: struct { found_type: SemaType },
        InvalidIndexType: struct { found: SemaType, left: Indexable },
        NamedFieldsRequireStruct: struct { found: SemaType },
        DuplicateField: struct { name: []const u8 },
        DuplicateFieldInit: struct { name: []const u8 },
        UnknownField: struct { name: []const u8, struct_name: []const u8 },
        MissingField: struct { name: []const u8, struct_name: []const u8 },
        InvalidVoidType: struct { context: []const u8 },

        pub fn toMessage(self: Kind, writer: *std.Io.Writer) !void {
            switch (self) {
                .ParseIntegerOverflow => try writer.writeAll("integer literal overflowed while parsing"),
                .MissingRightHandSideExpression => try writer.writeAll("expected an expression after the operator"),
                .InvalidLeftHandSideDeclaration => try writer.writeAll("invalid expression on the left-hand side of a declaration"),
                .MissingType => try writer.writeAll("expected a type in this declaration"),
                .ExpectedToken => |e| try writer.print("expected \"{s}\" found \"{s}\"", .{ @tagName(e.expected), @tagName(e.found) }),
                .UnexpectedTokenInType => |u| try writer.print("unexpected token \"{s}\" in type expression", .{@tagName(u.found)}),
                .UnexpectedToken => |u| try writer.print("unexpected token \"{s}\"", .{@tagName(u.found)}),
                .RedundantConst => try writer.print("redundant const modifier", .{}),
                .RedundantFinal => try writer.print("redundant final modifier", .{}),
                .ArraySizeTypeInfer => try writer.print("cannot infer array size at type level", .{}),
                .IllegalArraySizeExpression => try writer.print("cannot use expression for array indexing", .{}),

                .InvalidBinaryExpressionType => |e| try writer.print("operator '{s}' cannot be applied to type \"{f}\" and \"{f}\"", .{ @tagName(e.operator), e.left, e.right }),
                .IdentifierAlreadyExist => |e| try writer.print("cannot redeclare identifier \"{s}\"", .{e.identifier}),
                .TypeMismatch => |e| try writer.print("expected type \"{f}\", found type \"{f}\" instead", .{ e.expected, e.found }),
                .ReturnTypeMismatch => |e| try writer.print("expected return type \"{f}\", found return type \"{f}\" instead", .{ e.expected, e.found }),
                .ImpossibleComparison => |e| try writer.print("cannot perform comparison \"{s}\" to type \"{f}\" and \"{f}\"", .{ @tagName(e.operator), e.left, e.right }),
                .InvalidLeftHandSideAssignment => try writer.print("cannot assign to this expression", .{}),
                .UndefinedIdentifier => |i| try writer.print("cannot resolve identifier \"{s}\"", .{i.identifier}),
                .UndefinedType => |i| try writer.print("cannot resolve type \"{s}\"", .{i.identifier}),
                .FinalIdentifierAssignment => |f| try writer.print("cannot assign to final identifier \"{s}\"", .{f.identifier}),
                .ConstIdentifierAssignment => |f| try writer.print("cannot assign to constant identifier \"{s}\"", .{f.identifier}),
                .ConstIdentifierMutation => |f| try writer.print("cannot mutate constant identifier \"{s}\"", .{f.identifier}),
                .FunctionAssignment => |f| try writer.print("cannot assign to a function \"{s}\"", .{f.identifier}),
                .StructAssignment => |f| try writer.print("cannot assign to a struct \"{s}\"", .{f.identifier}),
                .VoidValueStorage => |v| try writer.print("cannot store a value of type \"void\" to \"{s}\"", .{v.identifier}),
                .IllegalReturn => try writer.print("cannot return from outside a function", .{}),
                .IntegerOverflow => try writer.print("integer value overflowed", .{}),
                .MissingReturn => |r| try writer.print("missing return in function \"{s}\"", .{r.name}),
                .IllegalTopLevelStatement => try writer.print("statement not allowed at top level", .{}),
                .NestedFunctionDeclaration => try writer.print("function declaration not allowed inside a function", .{}),
                .NonCallableCallee => |n| try writer.print("cannot call value of type \"{f}\"", .{n.callee_type}),
                .TooManyArguments => |t| try writer.print("too many arguments. expected {d} but got {d} instead", .{ t.expected, t.found }),
                .TooFewArguments => |t| try writer.print("too few arguments. expected {d} but got {d} instead", .{ t.expected, t.found }),
                .IllegalBreak => try writer.print("cannot break outside a loop", .{}),
                .NonVoidMainReturnType => |f| try writer.print("\"main\" function must return a \"void\" type. found {f}", .{f.found}),
                .ArraySizeNotConstant => try writer.writeAll("array size must be a compile-time constant"),
                .InvalidArraySize => |a| try writer.print("invalid array size {d}", .{a.value}),
                .ArraySizeMismatch => |a| try writer.print("expected at most {d} elements but got {d} instead", .{ a.expected, a.found }),
                .ArraySizeTooLarge => |a| try writer.print("compile-time array size {d} exceeds the maximum encodable value of {d}", .{ a.found, a.max }),
                .CannotInferLiteralType => try writer.print("cannot infer the type of this literal, it needs a type for context", .{}),
                .InvalidIndexOperand => |f| try writer.print("cannot index value of type \"{f}\"", .{f.found_type}),
                .InvalidIndexType => |f| try writer.print("invalid index type \"{f}\" to a {s}", .{ f.found, fmtIndexLeft(f.left) }),
                .NamedFieldsRequireStruct => |n| try writer.print("named fields can only initialize a struct, found type \"{f}\"", .{n.found}),
                .DuplicateField => |d| try writer.print("duplicate field \"{s}\"", .{d.name}),
                .DuplicateFieldInit => |d| try writer.print("field \"{s}\" is initialized more than once", .{d.name}),
                .UnknownField => |u| try writer.print("struct \"{s}\" has no field \"{s}\"", .{ u.struct_name, u.name }),
                .MissingField => |m| try writer.print("missing field \"{s}\" in initializer of struct \"{s}\"", .{ m.name, m.struct_name }),
                .InvalidVoidType => |v| try writer.print("\"void\" cannot be used as {s}", .{v.context}),
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

fn fmtIndexLeft(idx: IglotDiagnostic.Indexable) []const u8 {
    return switch (idx) {
        .fixed_array => "fixed array",
    };
}
