const nyan = @import("nyancore");

const UI = @import("ui/ui.zig").UI;
const Global = @import("global.zig");

const std = @import("std");

pub fn main() !void {
    const allocator: *std.mem.Allocator = std.testing.allocator;

    var renderer: nyan.DefaultRenderer = undefined;
    renderer.init("Main Renderer", allocator);

    var ui: UI = undefined;
    ui.init(allocator);

    try renderer.renderCtx.append(&ui.nyanui.system);
    try renderer.renderFns.append(nyan.UI.render);

    const systems: []*nyan.System = &[_]*nyan.System{
        &renderer.system,
        &ui.nyanui.system,
    };

    nyan.initGlobalData(allocator);
    defer nyan.deinitGlobalData();

    nyan.app.init("lamia", allocator, systems);
    defer nyan.app.deinit();

    Global.main_scene.init();
    defer Global.main_scene.deinit();

    try nyan.app.start();
}
