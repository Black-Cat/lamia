const std = @import("std");
const builtin = @import("builtin");

const nyan_build = @import("nyancore/build.zig");

const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var lamia = b.addExecutable(.{
        .name = "lamia",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // As at the current version zig 0.9.1, zig build-exe res support is broken
    // Removed for now, untill fixed
    // https://github.com/ziglang/zig/issues/6488
    // When fixed, remove setting icon in main.zig for windows
    const os_tag = if (target.os_tag != null) target.os_tag.? else builtin.os.tag;
    if (false and os_tag == .windows) {
        var args = std.ArrayList([]const u8).init(b.allocator);
        defer args.deinit();

        if (builtin.os.tag == .windows) {
            args.appendSlice(&[_][]const u8{ "windress", "icon.rc", "-0", "coff", "-o", "zig-cache/icon.res" }) catch unreachable;
            const child = std.ChildProcess.init(args.items, b.allocator) catch unreachable;
            _ = child.spawnAndWait() catch unreachable;
            child.deinit();
        } else {
            args.appendSlice(&[_][]const u8{ "llvm-rc", "icon.rc" }) catch unreachable;
            const child_res = std.ChildProcess.init(args.items, b.allocator) catch unreachable;
            _ = child_res.spawnAndWait() catch unreachable;
            child_res.deinit();

            args.clearRetainingCapacity();

            args.appendSlice(&[_][]const u8{ "mv", "icon.res", "zig-cache/icon.res" }) catch unreachable;
            const child_mv = std.ChildProcess.init(args.items, b.allocator) catch unreachable;
            _ = child_mv.spawnAndWait() catch unreachable;
            child_mv.deinit();
        }

        lamia.addObjectFile("zig-cache/icon.res");
    }

    const vulkan_validation: bool = b.option(bool, "vulkan-validation", "Use vulkan validation layer, useful for vulkan development. Needs Vulkan SDK") orelse false;
    const enable_tracing: bool = b.option(bool, "enable-tracing", "Enable tracing with tracy v0.8") orelse false;
    const panic_on_all_errors: bool = b.option(bool, "panic-on-all-errors", "Panic on all errors") orelse false;

    lamia.linkSystemLibrary("c");

    var nyancoreLib = nyan_build.addStaticLibrary(b, lamia, "nyancore/", vulkan_validation, enable_tracing, panic_on_all_errors, true);

    lamia.linkLibrary(nyancoreLib);
    lamia.step.dependOn(&nyancoreLib.step);

    b.installArtifact(lamia);

    const run_target = b.step("run", "Run lamia");
    const run = b.addRunArtifact(lamia);

    if (b.args) |args|
        run.addArgs(args);

    run.step.dependOn(b.getInstallStep());
    run_target.dependOn(&run.step);
}
