const nyan = @import("nyancore");

const UI = @import("ui/ui.zig").UI;

const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var renderer: nyan.DefaultRenderer = undefined;
    renderer.init("Main Renderer", std.testing.allocator);

    var ui: UI = undefined;
    ui.init();

    try renderer.renderCtx.append(&ui.nyanui.system);
    try renderer.renderFns.append(nyan.UI.render);

    const systems: []*nyan.System = &[_]*nyan.System{
        &renderer.system,
        &ui.nyanui.system,
    };

    nyan.initGlobalData(std.testing.allocator);
    defer nyan.deinitGlobalData();

    nyan.app.init("lamia", std.testing.allocator, systems);
    defer nyan.app.deinit();

    try nyan.app.start();
}
