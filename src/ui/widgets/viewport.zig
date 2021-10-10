const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;

pub const Viewport = struct {
    window: nyan.Widgets.Window,
    visible: bool,
    window_class: *nc.ImGuiWindowClass,

    viewport_texture: nyan.ViewportTexture,
    render_pass: nyan.ScreenRenderPass,

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

        self.visible = false;
        self.window_class = window_class;
    }

    pub fn deinit(self: *Viewport) void {}

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        self.viewport_texture.init("Viewport Texture", nyan.global_render_graph.in_flight, 128, 128, nyan.app.allocator);
        self.viewport_texture.alloc();
        nyan.global_render_graph.addViewportTexture(&self.viewport_texture);

        self.render_pass.init("Viewport Render Pass", nyan.app.allocator);
        self.render_pass.rg_pass.appendReadResource(&self.viewport_texture.rg_resource);
        nyan.global_render_graph.passes.append(&self.render_pass.rg_pass) catch unreachable;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        self.viewport_texture.deinit();
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        nc.igSetNextWindowClass(self.window_class);
        const wasVisible = self.visible;
        self.visible = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);

        if (wasVisible != self.visible) {
            if (self.visible) {
                self.render_pass.rg_pass.appendWriteResource(&nyan.global_render_graph.final_swapchain.rg_resource);
            } else {
                self.render_pass.rg_pass.removeWriteResource(&nyan.global_render_graph.final_swapchain.rg_resource);
            }
            nyan.global_render_graph.needs_rebuilding = true;
        }

        var min_pos: nc.ImVec2 = undefined;
        var max_pos: nc.ImVec2 = undefined;
        nc.igGetWindowContentRegionMin(&min_pos);
        nc.igGetWindowContentRegionMax(&max_pos);

        var window_pos: nc.ImVec2 = undefined;
        nc.igGetWindowPos(&window_pos);

        const cur_width: u32 = @floatToInt(u32, @round(max_pos.x - min_pos.x));
        const cur_height: u32 = @floatToInt(u32, @round(max_pos.y - min_pos.y));

        if (self.visible and (cur_width != self.viewport_texture.width or cur_height != self.viewport_texture.height)) {
            self.viewport_texture.width = cur_width;
            self.viewport_texture.height = cur_height;

            self.viewport_texture.resize(&nyan.global_render_graph);
        }

        nc.igImage(
            @ptrCast(*c_void, self), //self.viewport_texture.descriptor_sets),
            .{ .x = max_pos.x - min_pos.x, .y = max_pos.y - min_pos.y },
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 1 },
            .{ .x = 1, .y = 1, .z = 1, .w = 1 },
            .{ .x = 0, .y = 0, .z = 0, .w = 0 },
        );

        nc.igEnd();
    }
};
