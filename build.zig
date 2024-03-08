const std = @import("std");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "random",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const install_assets_step = b.addInstallDirectory(.{
        .source_dir = .{ .path = "pages" },
        .install_dir = .{ .custom = "" },
        .install_subdir = "bin/pages",
    });

    exe.step.dependOn(&install_assets_step.step);
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
