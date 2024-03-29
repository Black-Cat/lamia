const std = @import("std");

const nyan = @import("nyancore");
const builtin = @import("builtin");

const UI = @import("ui/ui.zig").UI;
const Global = @import("global.zig");

const importStepFile = @import("ui/import_step.zig").importStepFile;

const FileExtension = enum {
    step,
    stp,
    ls,
    unknown,
};

fn setIcon(context: *anyopaque) void {
    _ = context;

    nyan.app.set_icon(@embedFile("./icon.ico"));
}

fn setDefaultSettings() void {
    var config: *nyan.Config = nyan.app.config;
    config.putBool("swapchain_vsync", true);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator: std.mem.Allocator = gpa.allocator();

    var renderer: nyan.DefaultRenderer = undefined;
    renderer.init("Main Renderer", allocator);

    var ui: UI = undefined;
    ui.init(allocator);

    try nyan.global_render_graph.passes.append(&ui.nyanui.rg_pass);

    Global.file_watcher.init(allocator);
    defer Global.file_watcher.deinit();

    Global.init_cameras(allocator);
    defer Global.deinit_cameras();

    nyan.initGlobalData(allocator);
    defer nyan.deinitGlobalData();

    var systems = nyan.Application.SystemsMap.init(allocator);
    defer systems.deinit();

    systems.put(nyan.typeId(@TypeOf(renderer)), &renderer.system) catch unreachable;
    systems.put(nyan.typeId(@TypeOf(ui)), &ui.system) catch unreachable;
    systems.put(nyan.typeId(@TypeOf(Global.file_watcher)), &Global.file_watcher.system) catch unreachable;

    nyan.app.init("lamia", allocator, &systems);
    defer nyan.app.deinit();

    setDefaultSettings();

    // X11 Doesn't allow to set icon at startup due to it's multiple process async nature
    // There is also no adequate way to check if icon was set or not

    // Until res files are fixed (https://github.com/ziglang/zig/issues/6488) both windows and linux use this path
    if (builtin.target.os.tag == .linux)
        nyan.app.delayed_tasks.append(.{
            .task = setIcon,
            .context = undefined,
            .delay = 0.0001,
        }) catch unreachable;

    Global.main_scene.init();
    defer Global.main_scene.deinit();

    if (nyan.app.args.get("")) |path| {
        var file_extension_it = std.mem.splitBackwards(u8, path, ".");
        if (file_extension_it.next()) |file_extension_slice| {
            var file_extension_lower: []u8 = std.ascii.allocLowerString(allocator, file_extension_slice) catch unreachable;
            defer allocator.free(file_extension_lower);

            var file_extension: FileExtension = std.meta.stringToEnum(FileExtension, file_extension_lower) orelse FileExtension.unknown;
            switch (file_extension) {
                .step, .stp => importStepFile(path) catch |err| nyan.printZigErrorNoPanic("Main", "Couldn't load STEP file from args", err),
                .ls, .unknown => Global.main_scene.load(path) catch |err| nyan.printZigErrorNoPanic("Main", "Couldn't load lamia scene from args", err),
            }
        }
    }

    try nyan.app.initSystems();
    defer nyan.app.deinitSystems();

    try nyan.app.mainLoop();
}
