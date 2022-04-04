const std = @import("std");

const nyan_build = @import("nyancore/build.zig");

const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    var lamia = b.addExecutable("lamia", "src/main.zig");

    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const vulkan_validation: ?bool = b.option(bool, "vulkan-validation", "Use vulkan validation layer, useful for vulkan development. Needs Vulkan SDK");

    lamia.setTarget(target);
    lamia.setBuildMode(mode);
    lamia.linkSystemLibrary("c");

    var nyancoreLib = nyan_build.addStaticLibrary(b, lamia, "nyancore/", vulkan_validation orelse false);

    lamia.linkLibrary(nyancoreLib);
    lamia.step.dependOn(&nyancoreLib.step);

    lamia.install();

    const run_target = b.step("run", "Run lamia");
    const run = lamia.run();

    if (b.args) |args|
        run.addArgs(args);

    run.step.dependOn(b.getInstallStep());
    run_target.dependOn(&run.step);
}
