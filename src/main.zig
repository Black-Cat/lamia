const nyan = @import("nyancore");

const UI = @import("ui/ui.zig").UI;
const Global = @import("global.zig");

const std = @import("std");

pub fn main() !void {
    const allocator: std.mem.Allocator = std.testing.allocator;

    var renderer: nyan.DefaultRenderer = undefined;
    renderer.init("Main Renderer", allocator);

    var ui: UI = undefined;
    ui.init(allocator);

    try nyan.global_render_graph.passes.append(&ui.nyanui.render_pass);

    Global.file_watcher.init(allocator);
    defer Global.file_watcher.deinit();

    const systems: []*nyan.System = &[_]*nyan.System{
        &renderer.system,
        &ui.nyanui.system,
        &Global.file_watcher.system,
    };

    nyan.initGlobalData(allocator);
    defer nyan.deinitGlobalData();

    nyan.app.init("lamia", allocator, systems);
    defer nyan.app.deinit();

    Global.main_scene.init();
    defer Global.main_scene.deinit();

    if (nyan.app.args.get("")) |path|
        Global.main_scene.load(path) catch nyan.printErrorNoPanic("Main", "Couldn't load path from args");

    try nyan.app.start();
}
