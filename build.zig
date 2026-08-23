const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_time_path = "src/build_time.zig";
    {
        const now = std.Io.Clock.real.now(b.graph.io);

        const contents = std.fmt.allocPrint(
            b.allocator,
            \\ //! DO NOT TOUCH! This file is NOT intended for editing.
            \\ //! The `../build.zig` file will override this on every build.
            \\
            \\ pub const timestamp: i64 = {d};
        ,
            .{now.toSeconds()},
        ) catch @panic("OOM");

        std.Io.Dir.cwd().writeFile(b.graph.io, .{
            .sub_path = build_time_path,
            .data = contents,
        }) catch |err| std.debug.panic("failed to write build_time.zig: {t}", .{err});
    }

    const exe = b.addExecutable(.{
        .name = "cisco",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const cisco_information = b.createModule(.{
        .root_source_file = b.path("build.zig.zon"),
    });
    exe.root_module.addImport("cisco_information", cisco_information);

    const build_time = b.createModule(.{
        .root_source_file = b.path(build_time_path),
    });
    exe.root_module.addImport("build_time", build_time);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
