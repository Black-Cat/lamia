const nyan = @import("nyancore");
const builtin = @import("builtin");

const UI = @import("ui/ui.zig").UI;
const Global = @import("global.zig");

const std = @import("std");

fn setIcon(context: *anyopaque) void {
    _ = context;

    nyan.app.set_icon(@embedFile("../icon.ico"));
}

pub fn main() !void {
    const allocator: std.mem.Allocator = std.testing.allocator;

    var renderer: nyan.DefaultRenderer = undefined;
    renderer.init("Main Renderer", allocator);

    var ui: UI = undefined;
    ui.init(allocator);

    try nyan.global_render_graph.passes.append(&ui.nyanui.render_pass);

    Global.file_watcher.init(allocator);
    defer Global.file_watcher.deinit();

    Global.init_cameras(allocator);
    defer Global.deinit_cameras();

    const systems: []*nyan.System = &[_]*nyan.System{
        &renderer.system,
        &ui.nyanui.system,
        &Global.file_watcher.system,
    };

    nyan.initGlobalData(allocator);
    defer nyan.deinitGlobalData();

    nyan.app.init("lamia", allocator, systems);
    defer nyan.app.deinit();

    // X11 Doesn't allow to set icon at startup due to it's multiple process async nature
    // There is also no adequate way to check if icon was set or not

    // Until res files are fixed (https://github.com/ziglang/zig/issues/6488) both windows and linux use this path
    //if (builtin.target.os.tag == .linux)
    nyan.app.delayed_tasks.append(.{
        .task = setIcon,
        .context = undefined,
        .delay = 0.0001,
    }) catch unreachable;

    Global.main_scene.init();
    defer Global.main_scene.deinit();

    if (nyan.app.args.get("")) |path|
        Global.main_scene.load(path) catch nyan.printErrorNoPanic("Main", "Couldn't load path from args");

    try nyan.app.start();
}
