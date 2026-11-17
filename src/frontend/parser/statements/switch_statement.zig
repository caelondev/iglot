//! Copyright (C) 2026 caelondev
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU Affero General Public License as published
//! by the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//! GNU Affero General Public License for more details.
//!
//! You should have received a copy of the GNU Affero General Public License
//! along with this program. If not, see <https://www.gnu.org/licenses/>.
//!
//! Parses `switch` statements.
//!
//! A `switch` statement is divided into two parts. The scrutinee expression
//! is first parsed as a regular expression, following the `switch` keyword
//! and terminated by a colon (`:`). This expression is evaluated once at
//! runtime, and its value is compared against each arm in order.
//!
//! After the colon, the parser consumes a brace-delimited list of arms.
//! Each arm consists of a pattern, a fat arrow (`=>`), and a body. The
//! body is either a block or a single statement. Patterns in this initial
//! implementation are literals, such as `100`.
//!
//! The `else` arm is the catch-all. It matches any value not matched by
//! a previous arm, including a failed parse. It must appear last, and
//! only one `else` arm is allowed.
//!
//! The parser does not enforce semantic rules here, such as exhaustiveness,
//! reachability, or `else` placement. Those checks belong to sema.
//!
//! Parsing stops when the closing brace is reached. An empty arm list is
//! rejected, as a `switch` with no arms can never execute a body.

const std = @import("std");
const ast = @import("../ast.zig");
const IglotParser = @import("../parser.zig").IglotParser;
const Span = @import("../../lexer/tokens.zig").Span;

pub fn parseSwitchStatement(
    parser: *IglotParser,
    allocator: std.mem.Allocator,
) !?ast.Statement {}
