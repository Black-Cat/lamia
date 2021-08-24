const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;
const Scene = @import("../../scene/scene.zig").Scene;
const SceneNode = @import("../../scene/scene_node.zig").SceneNode;

const scene_tree_key_open: []const u8 = "ui_widgets_scene_tree_open";

pub const SceneTree = struct {
    window: nyan.Widgets.Window,
    main_scene: Scene,

    selected_scene_node: *?*SceneNode,
    clicked_node: ?*SceneNode,

    pub fn init(self: *SceneTree, selected_scene_node: *?*SceneNode) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = false,
            .strId = "Scene Tree",
        };
        self.selected_scene_node = selected_scene_node;
        self.clicked_node = null;
    }

    pub fn deinit(self: *SceneTree) void {
        self.main_scene.deinit();
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);
        const open: bool = std.mem.eql(u8, nyan.app.config.map.get(scene_tree_key_open) orelse "1", "1");
        self.window.open = open;

        self.main_scene.init();
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);
        nyan.app.config.map.put(scene_tree_key_open, if (self.window.open) "1" else "0") catch unreachable;
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);

        if (!window.open)
            return;

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);
        if (nc.igButton("Add Node", .{ .x = 0, .y = 0 }))
            self.addNode();

        self.drawSceneHeirarchy();

        nc.igEnd();
    }

    fn addNode(self: *SceneTree) void {
        var node: *SceneNode = self.main_scene.root.add();
        node.init("New Node");
    }

    fn addSelectedFlag(flag: nc.ImGuiTreeNodeFlags, node: *SceneNode, selected_node: ?*SceneNode) nc.ImGuiTreeNodeFlags {
        if (node == selected_node)
            return flag | nc.ImGuiTreeNodeFlags_Selected;
        return flag;
    }

    fn drawSceneLeaf(self: *SceneTree, node: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = addSelectedFlag(nc.ImGuiTreeNodeFlags_Bullet, node, self.selected_scene_node.*);
        const opened: bool = nc.igTreeNodeEx_Ptr(node, node_flags, &node.name);
        if (nc.igIsItemClicked(0)) // LMB
            self.clicked_node = node;
        if (opened)
            nc.igTreePop();
    }

    fn drawSceneNode(self: *SceneTree, node: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = addSelectedFlag(nc.ImGuiTreeNodeFlags_OpenOnArrow, node, self.selected_scene_node.*);
        const opened: bool = nc.igTreeNodeEx_Ptr(node, node_flags, &node.name);

        if (nc.igIsItemClicked(0) and !nc.igIsItemToggledOpen()) // LMB
            self.clicked_node = node;

        if (opened) {
            for (node.children.items) |child| {
                if (child.childrenCount() > 0) {
                    self.drawSceneNode(child);
                } else {
                    self.drawSceneLeaf(child);
                }
            }
            nc.igTreePop();
        }
    }

    fn drawSceneNodeChildren(self: *SceneTree, node: *SceneNode) void {
        for (node.children.items) |child| {
            if (child.childrenCount() > 0) {
                self.drawSceneNode(child);
            } else {
                self.drawSceneLeaf(child);
            }
        }
    }

    fn drawSceneHeirarchy(self: *SceneTree) void {
        if (self.main_scene.root.childrenCount() == 0) {
            nc.igText("Empty Scene");
            return;
        }

        self.clicked_node = null;

        self.drawSceneNodeChildren(&self.main_scene.root);

        if (self.clicked_node != null)
            self.selected_scene_node.* = self.clicked_node;
    }
};
