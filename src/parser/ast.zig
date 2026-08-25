//! Copyright (C) 2026  caelondev
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU Affero General Public License as published
//! by the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU Affero General Public License for more details.
//!
//! You should have received a copy of the GNU Affero General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.
//!
//! This module defines the abstract syntax tree (AST) used to represent
//! parsed Cisco source code.
//!
//! `Node` is the common root of the AST and associates an expression or
//! statement with its source span. Nodes retain their source-location
//! information so that later compiler stages can report diagnostics
//! against the original source.
//!
//! Expressions represent values produced by evaluating source code,
//! including integer, floating-point, string, and boolean literals.
//!
//! Statements represent complete language constructs. An
//! `ExpressionStatement` wraps an expression when it is used as a
//! standalone statement.
//!
//! The AST is composed of tagged unions, allowing compiler stages such as
//! semantic analysis and code generation to recursively inspect the kind
//! of each expression or statement without relying on runtime type
//! information.

const tokens = @import("../lexer/tokens.zig");

pub const Program = struct { body: []Statement };

pub const Node = struct {
    span: tokens.Span,
    kind: Kind,

    pub const Kind = union(enum) {
        expression: Expression,
        statement: Statement,
    };
};

pub const Expression = struct {
    span: tokens.Span,
    expr: union(enum) {
        // literals
        integer: IntegerExpression,
        float: FloatExpression,
        string: StringExpression,
        identifier: IdentifierExpression,

        // le regular expressions
        binary: BinaryExpression,
    },
};

pub const Statement = union(enum) {
    expression: ExpressionStatement,
};

pub const IntegerExpression = struct {
    value: i128,
};

pub const FloatExpression = struct {
    value: f64,
};

pub const StringExpression = struct {
    value: []const u8,
};

pub const IdentifierExpression = struct {
    value: []const u8,
};

pub const BinaryExpression = struct {
    left: *const Expression,
    right: *const Expression,
    operator: tokens.TokenKind,
};

pub const ExpressionStatement = struct {
    expression: Expression,
    span: tokens.Span,
};
