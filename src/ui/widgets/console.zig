const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;

const config_key_open: []const u8 = "ui_widgets_console_open";

pub const Console = struct {
    window: nyan.Widgets.Window,

    pub fn init(self: *Console) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = false,
            .strId = "Console",
        };
    }

    pub fn deinit(self: *Console) void {
        _ = self;
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Console = @fieldParentPtr(Console, "window", window);
        const open: bool = std.mem.eql(u8, nyan.app.config.map.get(config_key_open) orelse "0", "1");
        self.window.open = open;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Console = @fieldParentPtr(Console, "window", window);
        nyan.app.config.map.put(config_key_open, if (self.window.open) "1" else "0") catch unreachable;
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Console = @fieldParentPtr(Console, "window", window);

        if (!window.open)
            return;

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);
        nc.igEnd();
    }
};
