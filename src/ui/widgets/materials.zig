const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;
const Global = @import("../../global.zig");

const SceneNode = @import("../../scene/scene_node.zig").SceneNode;
const Scene = @import("../../scene/scene.zig").Scene;

const NodeType = @import("../../nodes/node_type.zig").NodeType;
const node_collection = @import("../../nodes/node_collection.zig");

const config_key_open: []const u8 = "ui_widgets_materials_open";

pub const Materials = struct {
    window: nyan.Widgets.Window,

    selected_scene_node: *?*SceneNode,

    pub fn init(self: *Materials, selected_scene_node: *?*SceneNode) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
            .strId = "Materials",
        };

        self.selected_scene_node = selected_scene_node;
    }

    pub fn deinit(self: *Materials) void {
        _ = self;
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Materials = @fieldParentPtr(Materials, "window", window);
        const open: bool = std.mem.eql(u8, nyan.app.config.map.get(config_key_open) orelse "1", "1");
        self.window.open = open;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Materials = @fieldParentPtr(Materials, "window", window);
        nyan.app.config.map.put(config_key_open, if (self.window.open) "1" else "0") catch unreachable;
    }

    fn addMaterial(scene: *Scene, mat_type: *const NodeType) void {
        var node: *SceneNode = scene.materials.add();
        node.init(mat_type, mat_type.name, &scene.materials);
    }

    fn addSelectedFlag(flag: nc.ImGuiTreeNodeFlags, node: *SceneNode, selected_node: ?*SceneNode) nc.ImGuiTreeNodeFlags {
        if (node == selected_node)
            return flag | nc.ImGuiTreeNodeFlags_Selected;
        return flag;
    }

    fn drawMaterial(self: *Materials, mat: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = addSelectedFlag(nc.ImGuiTreeNodeFlags_Bullet, mat, self.selected_scene_node.*);

        const opened: bool = nc.igTreeNodeEx_Ptr(mat, node_flags, &mat.name);

        if (nc.igIsItemClicked(0)) // LMB
            self.selected_scene_node.* = mat;

        if (opened)
            nc.igTreePop();
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Materials = @fieldParentPtr(Materials, "window", window);

        if (!window.open)
            return;

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);

        if (nc.igButton("Add Material", .{ .x = 0, .y = 0 }))
            nc.igOpenPopup("add_material_popup", nc.ImGuiPopupFlags_None);

        for (Global.main_scene.materials.children.items) |mat|
            self.drawMaterial(mat);

        if (nc.igBeginPopup("add_material_popup", nc.ImGuiWindowFlags_None)) {
            for (&node_collection.materials) |*mat_type| {
                if (nc.igSelectable_Bool(mat_type.name.ptr, false, nc.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 }))
                    addMaterial(&Global.main_scene, mat_type);
            }

            nc.igEndPopup();
        }

        nc.igEnd();
    }
};
