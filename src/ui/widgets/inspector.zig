const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;
const Global = @import("../../global.zig");

const SceneNode = @import("../../scene/scene_node.zig").SceneNode;
const GizmoStorage = @import("viewport_gizmos.zig").GizmoStorage;

const config_key_open: []const u8 = "ui_widgets_inspector_open";

pub const Inspector = struct {
    window: nyan.Widgets.Window,

    selected_scene_node: *?*SceneNode,

    gizmo_storage: *GizmoStorage,

    pub fn init(self: *Inspector, selected_scene_node: *?*SceneNode, gizmo_storage: *GizmoStorage) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
            .strId = "Inspector",
        };

        self.selected_scene_node = selected_scene_node;

        self.gizmo_storage = gizmo_storage;
    }

    pub fn deinit(self: *Inspector) void {}

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Inspector = @fieldParentPtr(Inspector, "window", window);
        const open: bool = std.mem.eql(u8, nyan.app.config.map.get(config_key_open) orelse "1", "1");
        self.window.open = open;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Inspector = @fieldParentPtr(Inspector, "window", window);
        nyan.app.config.map.put(config_key_open, if (self.window.open) "1" else "0") catch unreachable;
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Inspector = @fieldParentPtr(Inspector, "window", window);

        if (!window.open)
            return;

        if (self.gizmo_storage.scene_node != self.selected_scene_node.*)
            self.gizmo_storage.fillFromNode(self.selected_scene_node.*);

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);

        if (self.selected_scene_node.*) |node| {
            self.drawSelectedNode(node);
        } else {
            nc.igText("No node selected");
        }

        nc.igEnd();
    }

    fn drawSelectedNode(self: *Inspector, node: *SceneNode) void {
        _ = nc.igInputText("Name", &node.name, SceneNode.NAME_SIZE, 0, null, null);

        if (nc.igButton("Delete", .{ .x = 0, .y = 0 })) {
            self.selected_scene_node.* = null;

            _ = node.parent.?.removeChild(node);
            node.deinit();

            Global.main_scene.recompile();
            return;
        }

        var edited: bool = false;
        for (node.node_type.properties) |*prop|
            edited = prop.drawFn(prop, &node.buffer) or edited;

        if (edited) {
            if (node.node_type.has_edit_callback) {
                node.node_type.edit_callback(&node.buffer);
            }
            Global.main_scene.recompile();
        }
    }
};
