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

    clicked_node: ?*SceneNode,

    pub fn init(self: *SceneTree) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = false,
            .strId = "Scene Tree",
        };
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

    fn drawSceneLeaf(self: *SceneTree, node: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = nc.ImGuiTreeNodeFlags_Bullet;
        const opened: bool = nc.igTreeNodeEx_Ptr(node, node_flags, &node.name);
        if (opened)
            nc.igTreePop();
    }

    fn drawSceneNode(self: *SceneTree, node: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = nc.ImGuiTreeNodeFlags_OpenOnArrow;
        const opened: bool = nc.igTreeNodeEx_Ptr(node, node_flags, &node.name);
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
        self.clicked_node = null;

        if (self.main_scene.root.childrenCount() > 0) {
            self.drawSceneNodeChildren(&self.main_scene.root);
        } else {
            nc.igText("Empty Scene");
        }
    }
};
