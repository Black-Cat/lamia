const std = @import("std");

const nyan_build = @import("nyancore/build.zig");

const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    var lamia = b.addExecutable("lamia", "src/main.zig");

    const mode = b.standardReleaseOptions();

    lamia.setBuildMode(mode);
    lamia.linkSystemLibrary("c");
    lamia.linkSystemLibrary("glfw");
    lamia.addPackage(.{
        .name = "nyancore",
        .path = "nyancore/src/main.zig",
    });

    var nyancoreLib = nyan_build.addStaticLibrary(b, lamia, "nyancore/", true);

    lamia.linkLibrary(nyancoreLib);
    lamia.step.dependOn(&nyancoreLib.step);

    lamia.install();

    const run_target = b.step("run", "Run lamia");
    const run = lamia.run();
    run.step.dependOn(b.getInstallStep());
    run_target.dependOn(&run.step);
}
