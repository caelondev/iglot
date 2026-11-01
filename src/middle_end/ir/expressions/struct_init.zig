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
//! Lowers struct initialization expressions to IR.
//!
//! By the time a struct init reaches the IR, sema has already resolved
//! field names to indices and ordered the values by declaration order, so
//! `fields[i]` is slot `i` of the struct. Names are not part of the
//! instruction. They live in the module's struct descriptor table, which
//! is what debug output and runtime printing read from.
//!
//! Lowering is one `struct_pack` instruction. Every field value is
//! evaluated first, in declaration order, and the instruction takes them
//! as operands plus the descriptor id. Like `array_pack`, the operand
//! vregs don't need to be adjacent, codegen moves them into a consecutive
//! window.

const std = @import("std");
const typed_ast = @import("../../../frontend/sema/typed_ast.zig");
const SemaType = @import("../../../frontend/sema/type_table.zig").SemaType;
const inst = @import("../instruction.zig");
const IglotIR = @import("../ir.zig").IglotIR;

/// `sema_type` is the struct type of the whole expression, used to look up
/// (or create) its descriptor.
pub fn buildStructInitExpr(
    ir: *IglotIR,
    allocator: std.mem.Allocator,
    s: *const typed_ast.TypedStructInitializationExpression,
    sema_type: SemaType,
) !?inst.VReg {
    const desc_id = try ir.internStruct(allocator, sema_type.@"struct");
    const values = try allocator.alloc(inst.VReg, s.fields.len);

    for (s.fields, values) |f, *slot| {
        slot.* = try ir.buildExpression(allocator, f) orelse return null;
    }

    const dest = ir.current_fn.newVReg();
    try ir.emit(allocator, .{
        .op = .struct_pack,
        .sema_type = sema_type,
        .result = dest,
        .operands = values,
        .data = .{ .struct_desc = desc_id },
    });
    return dest;
}
