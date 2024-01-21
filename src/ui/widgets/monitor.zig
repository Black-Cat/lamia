const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;

const frame_time_count: usize = 50;

const config_key_open: []const u8 = "ui_widgets_monitor_open";

pub const Monitor = struct {
    window: nyan.Widgets.Window,

    frame_time_min: f32 = 9999.0,
    frame_time_max: f32 = 0.0,

    current_frame: usize = 0,

    frame_times: [frame_time_count]f32 = [_]f32{0.0} ** frame_time_count,

    pub fn init(self: *Monitor) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = false,
            .strId = "Monitor",
        };
        self.current_frame = 0;
    }

    pub fn deinit(self: *Monitor) void {
        _ = self;
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Monitor = @fieldParentPtr(Monitor, "window", window);
        const open: bool = std.mem.eql(u8, nyan.app.config.map.get(config_key_open) orelse "1", "1");
        self.window.open = open;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Monitor = @fieldParentPtr(Monitor, "window", window);
        nyan.app.config.map.put(config_key_open, if (self.window.open) "1" else "0") catch unreachable;
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Monitor = @fieldParentPtr(Monitor, "window", window);

        if (!window.open)
            return;

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);

        var io: *nc.ImGuiIO = nc.igGetIO();
        const framerate: f32 = io.Framerate;
        const frame_time: f32 = 1000.0 / framerate; // In ms
        if (frame_time < self.frame_time_min)
            self.frame_time_min = frame_time;
        if (frame_time > self.frame_time_max)
            self.frame_time_max = frame_time;
        self.frame_times[self.current_frame] = frame_time;

        const graph_size: nc.ImVec2 = .{ .x = 0, .y = 80 };
        nc.igPlotLines_FloatPtr("", &self.frame_times, frame_time_count, @intCast(self.current_frame), "Frame Times", self.frame_time_min, self.frame_time_max, graph_size, @sizeOf(f32));
        nc.igText("%.3f ms/frame (%.1f FPS)", @as(f64, @floatCast(frame_time)), @as(f64, @floatCast(framerate)));

        self.current_frame = (self.current_frame + 1) % frame_time_count;

        nc.igEnd();
    }
};
