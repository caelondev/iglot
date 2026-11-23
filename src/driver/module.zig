const ast = @import("../frontend/parser/ast.zig");

pub const IglotModule = struct {
    id: u32,
    path: []const u8,
    source: []const u8, // kept alive for the whole compilation
    program: ast.Program,
    deps: []*IglotModule = &.{},
};
