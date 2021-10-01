const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;

pub const Viewport = struct {
    window: nyan.Widgets.Window,
    visible: bool,
    window_class: *nc.ImGuiWindowClass,

    pub fn init(self: *Viewport, comptime name: [:0]const u8, window_class: *nc.ImGuiWindowClass) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
            .strId = name,
        };

        self.visible = undefined;
        self.window_class = window_class;
    }

    pub fn deinit(self: *Viewport) void {}

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        nc.igSetNextWindowClass(self.window_class);
        self.visible = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);
        nc.igEnd();
    }
};
