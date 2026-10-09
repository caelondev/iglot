const std = @import("std");
const inst = @import("instruction.zig");
const Function = @import("function.zig").Function;
const BasicBlock = @import("basic_block.zig").BasicBlock;
const Module = @import("module.zig").Module;

pub fn simplifyCfg(allocator: std.mem.Allocator, module: *Module) !void {
    for (module.functions.items) |f| {
        if (f.blocks.items.len == 0) continue;
        threadJumps(f);
        try dropUnreachable(allocator, f);
        try mergeChains(allocator, f);
    }
}

fn targetRefs(ins: *inst.Instruction) [2]?*inst.BlockRef {
    return switch (ins.data) {
        .branch_target => |*t| .{ t, null },
        .cond_branch => |*cb| .{ &cb.true_block, &cb.false_block },
        else => .{ null, null },
    };
}

fn lastJump(block: *const BasicBlock) ?u32 {
    const items = block.instructions.items;
    if (items.len == 0) return null;
    return switch (items[items.len - 1].data) {
        .branch_target => |t| t.id,
        else => null,
    };
}

fn resolve(f: *const Function, start: u32) u32 {
    var cur = start;
    var steps: usize = 0;
    while (steps < f.blocks.items.len) : (steps += 1) {
        const b = f.blocks.items[cur];
        if (b.instructions.items.len != 1) break;
        cur = lastJump(b) orelse break;
    }
    return cur;
}

fn threadJumps(f: *Function) void {
    for (f.blocks.items) |b| {
        for (b.instructions.items) |*ins| {
            for (targetRefs(ins)) |maybe| {
                const t = maybe orelse continue;
                t.id = resolve(f, t.id);
            }
        }
    }
}

fn dropUnreachable(allocator: std.mem.Allocator, f: *Function) !void {
    const n = f.blocks.items.len;
    const seen = try allocator.alloc(bool, n);
    defer allocator.free(seen);
    @memset(seen, false);

    var stack: std.ArrayList(u32) = .empty;
    defer stack.deinit(allocator);

    // hardcode 0 because the entry point is always reachable
    try stack.append(allocator, 0);
    seen[0] = true;

    while (stack.items.len > 0) {
        const id = stack.items[stack.items.len - 1];
        stack.items.len -= 1;

        for (f.getBlock(.{ .id = id }).instructions.items) |*ins| {
            for (targetRefs(ins)) |maybe| {
                const t = maybe orelse continue;
                if (seen[t.id]) continue;
                seen[t.id] = true;
                try stack.append(allocator, t.id);
            }
        }
    }

    try compact(allocator, f, seen);
}

fn mergeChains(allocator: std.mem.Allocator, f: *Function) !void {
    const n = f.blocks.items.len;

    const pred = try allocator.alloc(u32, n);
    defer allocator.free(pred);
    @memset(pred, 0);
    pred[0] = 1;

    for (f.blocks.items) |b| {
        for (b.instructions.items) |*ins| {
            for (targetRefs(ins)) |maybe| {
                const t = maybe orelse continue;
                pred[t.id] += 1;
            }
        }
    }

    const keep = try allocator.alloc(bool, n);
    defer allocator.free(keep);
    @memset(keep, true);

    for (f.blocks.items, 0..) |a, a_id| {
        if (!keep[a_id]) continue;
        while (lastJump(a)) |b_id| {
            if (b_id == a_id or pred[b_id] != 1) break;
            const b = f.blocks.items[b_id];
            _ = a.instructions.pop(); // the br
            try a.instructions.appendSlice(allocator, b.instructions.items);
            keep[b_id] = false;
        }
    }

    try compact(allocator, f, keep);
}

fn compact(allocator: std.mem.Allocator, f: *Function, keep: []const bool) !void {
    const n = f.blocks.items.len;
    const new_id = try allocator.alloc(u32, n);
    defer allocator.free(new_id);

    var next: u32 = 0;
    for (0..n) |old| {
        if (!keep[old]) continue;
        new_id[old] = next;
        next += 1;
    }

    for (f.blocks.items, 0..) |b, old| {
        if (!keep[old]) continue;
        for (b.instructions.items) |*ins| {
            for (targetRefs(ins)) |maybe| {
                const t = maybe orelse continue;
                std.debug.assert(keep[t.id]);
                t.id = new_id[t.id];
            }
        }
    }

    var w: usize = 0;
    for (f.blocks.items, 0..) |b, old| {
        if (!keep[old]) continue;
        b.id = .{ .id = new_id[old] };
        f.blocks.items[w] = b;
        w += 1;
    }
    f.blocks.shrinkRetainingCapacity(w);
    f.next_block_id = next;
}
