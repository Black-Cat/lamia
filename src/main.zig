const nyan = @import("nyancore");

const std = @import("std");
const Allocator = std.mem.Allocator;

fn test_init(allocator: *Allocator) void {}
fn test_deinit() void {}
fn test_update(elapsed_time: f64) void {}

pub fn main() !void {
    var renderer: nyan.DefaultRenderer = undefined;
    renderer.init("Main Renderer", std.testing.allocator);

    var ui: nyan.UI = undefined;
    ui.init("Main UI");

    const systems: []*nyan.System = &[_]*nyan.System{
        &renderer.system,
        &ui.system,
    };

    nyan.initGlobalData(std.testing.allocator);
    defer nyan.deinitGlobalData();

    nyan.app.init("lamia", std.testing.allocator, systems);
    defer nyan.app.deinit();

    try nyan.app.start();
}
