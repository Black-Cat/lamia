const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;

const Viewport = @import("viewport.zig").Viewport;

pub const ViewportSpace = struct {
    window: nyan.Widgets.Window,
    viewport_window_class: nc.ImGuiWindowClass,
    dockspace_id: nc.ImGuiID,

    viewports: [3]Viewport,

    pub fn init(self: *ViewportSpace) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowFirstDraw,
            },
            .open = true,
            .strId = "Viewport Space",
        };
    }

    pub fn deinit(self: *ViewportSpace) void {}

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *ViewportSpace = @fieldParentPtr(ViewportSpace, "window", window);

        self.viewport_window_class = .{
            .ClassId = 0,
            .ParentViewportId = nc.igGetMainViewport()[0].ID,
            .ViewportFlagsOverrideSet = nc.ImGuiViewportFlags_None,
            .ViewportFlagsOverrideClear = nc.ImGuiViewportFlags_None,
            .DockingAlwaysTabBar = false,
            .DockingAllowUnclassed = false,

            .TabItemFlagsOverrideSet = nc.ImGuiViewportFlags_None,
            .DockNodeFlagsOverrideSet = nc.ImGuiViewportFlags_None,
            .DockNodeFlagsOverrideClear = nc.ImGuiViewportFlags_None,
        };

        self.viewports = [_]Viewport{undefined} ** 3;
        self.viewports[0].init("Viewport 0", &self.viewport_window_class);
        self.viewports[1].init("Viewport 1", &self.viewport_window_class);
        self.viewports[2].init("Viewport 2", &self.viewport_window_class);
    }

    fn windowDeinit(widget: *Widget) void {}

    fn windowFirstDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *ViewportSpace = @fieldParentPtr(ViewportSpace, "window", window);

        self.beginViewportSpace();

        self.viewport_window_class.ClassId = nc.igGetID_Str("Viewport Dockspace Class");
        self.dockspace_id = nc.igGetID_Str("Viewport Dockspace");

        nc.igDockSpace(self.dockspace_id, .{ .x = 0, .y = 0 }, nc.ImGuiDockNodeFlags_None, &self.viewport_window_class);

        for (self.viewports) |v|
            nc.igDockBuilderDockWindow(v.window.strId.ptr, self.dockspace_id);
        nc.igDockBuilderFinish(self.dockspace_id);

        for (self.viewports) |*v|
            v.window.widget.draw(&v.window.widget);

        nc.igEnd();

        widget.draw = windowDraw;
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *ViewportSpace = @fieldParentPtr(ViewportSpace, "window", window);

        self.beginViewportSpace();

        nc.igDockSpace(self.dockspace_id, .{ .x = 0, .y = 0 }, nc.ImGuiDockNodeFlags_None, &self.viewport_window_class);

        for (self.viewports) |*v|
            v.window.widget.draw(&v.window.widget);

        nc.igEnd();
    }

    fn beginViewportSpace(self: *ViewportSpace) void {
        const window_flags: nc.ImGuiWindowFlags = nc.ImGuiWindowFlags_NoTitleBar | nc.ImGuiWindowFlags_NoCollapse | nc.ImGuiWindowFlags_NoResize |
            nc.ImGuiWindowFlags_NoMove | nc.ImGuiWindowFlags_NoBringToFrontOnFocus | nc.ImGuiWindowFlags_NoNavFocus;

        nc.igPushStyleVar_Float(nc.ImGuiStyleVar_WindowRounding, 0.0);
        nc.igPushStyleVar_Float(nc.ImGuiStyleVar_WindowBorderSize, 0.0);
        nc.igPushStyleVar_Vec2(nc.ImGuiStyleVar_WindowPadding, .{ .x = 0, .y = 0 });
        _ = nc.igBegin(self.window.strId.ptr, &self.window.open, window_flags);
        nc.igPopStyleVar(3);
    }
};
