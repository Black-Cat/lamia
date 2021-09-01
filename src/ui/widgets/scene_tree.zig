const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;
const Scene = @import("../../scene/scene.zig").Scene;
const SceneNode = @import("../../scene/scene_node.zig").SceneNode;

const NodeCollection = @import("../../nodes/node_collection.zig");
const NodeType = @import("../../nodes/node_type.zig").NodeType;

const scene_tree_key_open: []const u8 = "ui_widgets_scene_tree_open";

pub const SceneTree = struct {
    window: nyan.Widgets.Window,
    main_scene: Scene,

    selected_scene_node: *?*SceneNode,
    clicked_node: ?*SceneNode,

    drag_from: ?*SceneNode,
    drop_to: ?*SceneNode,
    parent_insert: ?*SceneNode,
    parent_insert_index: usize,

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

        self.drag_from = null;
        self.drop_to = null;
        self.parent_insert = null;
        self.parent_insert_index = 0;
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

    fn drawNodeCollection(self: *SceneTree, collection: []const NodeType) void {
        for (collection) |node_type|
            if (nc.igSelectable_Bool(node_type.name.ptr, false, nc.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 }))
                self.addNode(&node_type);
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);

        if (!window.open)
            return;

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);
        if (nc.igButton("Add Node", .{ .x = 0, .y = 0 }))
            nc.igOpenPopup("add_node_popup", nc.ImGuiPopupFlags_None);

        self.drawSceneHeirarchy();

        if (nc.igBeginPopup("add_node_popup", nc.ImGuiWindowFlags_None)) {
            nc.igColumns(4, "nodes_columns", true);

            nc.igText("Surfaces");
            nc.igNextColumn();
            nc.igText("Modifiers");
            nc.igNextColumn();
            nc.igText("Combinators");
            nc.igNextColumn();
            nc.igText("Special");
            nc.igNextColumn();

            nc.igSeparator();

            self.drawNodeCollection(NodeCollection.surfaces[0..]);
            nc.igNextColumn();
            self.drawNodeCollection(NodeCollection.modifiers[0..]);
            nc.igNextColumn();
            self.drawNodeCollection(NodeCollection.combinators[0..]);
            nc.igNextColumn();
            self.drawNodeCollection(NodeCollection.special[0..]);

            nc.igColumns(1, null, true);
            nc.igSetCursorPosX(600);
            nc.igEndPopup();
        }

        nc.igEnd();
    }

    fn addNode(self: *SceneTree, node_type: *const NodeType) void {
        var node: *SceneNode = self.main_scene.root.add();
        node.init(node_type, node_type.name, &self.main_scene.root);
    }

    fn addSelectedFlag(flag: nc.ImGuiTreeNodeFlags, node: *SceneNode, selected_node: ?*SceneNode) nc.ImGuiTreeNodeFlags {
        if (node == selected_node)
            return flag | nc.ImGuiTreeNodeFlags_Selected;
        return flag;
    }

    fn drawSceneLeaf(self: *SceneTree, node: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = addSelectedFlag(nc.ImGuiTreeNodeFlags_Bullet, node, self.selected_scene_node.*);
        const opened: bool = nc.igTreeNodeEx_Ptr(node, node_flags, &node.name);
        self.sceneNodeDragDrop(node);
        if (nc.igIsItemClicked(0)) // LMB
            self.clicked_node = node;
        if (opened)
            nc.igTreePop();
    }

    fn drawSceneNode(self: *SceneTree, node: *SceneNode) void {
        const node_flags: nc.ImGuiTreeNodeFlags = addSelectedFlag(nc.ImGuiTreeNodeFlags_OpenOnArrow, node, self.selected_scene_node.*);
        const opened: bool = nc.igTreeNodeEx_Ptr(node, node_flags, &node.name);
        self.sceneNodeDragDrop(node);

        if (nc.igIsItemClicked(0) and !nc.igIsItemToggledOpen()) // LMB
            self.clicked_node = node;

        if (opened) {
            for (node.children.items) |child, i| {
                self.sceneNodeReorderBlock(node, i);
                if (child.childrenCount() > 0) {
                    self.drawSceneNode(child);
                } else {
                    self.drawSceneLeaf(child);
                }
            }
            self.sceneNodeReorderBlock(node, node.childrenCount());
            nc.igTreePop();
        }
    }

    fn drawSceneNodeChildren(self: *SceneTree, node: *SceneNode) void {
        for (node.children.items) |child, i| {
            self.sceneNodeReorderBlock(node, i);
            if (child.childrenCount() > 0) {
                self.drawSceneNode(child);
            } else {
                self.drawSceneLeaf(child);
            }
        }
        self.sceneNodeReorderBlock(node, node.childrenCount());
    }

    fn drawSceneHeirarchy(self: *SceneTree) void {
        if (self.main_scene.root.childrenCount() == 0) {
            nc.igText("Empty Scene");
            return;
        }

        self.clicked_node = null;

        self.drawSceneNodeChildren(&self.main_scene.root);

        if (self.drop_to) |drop_to| {
            var drag_from: *SceneNode = self.drag_from.?;
            if (!drop_to.hasParent(drag_from))
                drag_from.reparent(drop_to);

            self.drag_from = null;
            self.drop_to = null;
        }

        if (self.parent_insert) |parent_insert| {
            var drag_from: *SceneNode = self.drag_from.?;

            if (!parent_insert.hasParent(drag_from))
                drag_from.reorder(parent_insert, self.parent_insert_index);

            self.drag_from = null;
            self.parent_insert = null;
        }

        if (self.clicked_node != null)
            self.selected_scene_node.* = self.clicked_node;
    }

    fn sceneNodeDragDrop(self: *SceneTree, node: *SceneNode) void {
        if (nc.igBeginDragDropSource(nc.ImGuiDragDropFlags_SourceNoDisableHover | nc.ImGuiDragDropFlags_SourceNoHoldToOpenOthers)) {
            nc.igText("Moving \"%s\"", node.name);
            _ = nc.igSetDragDropPayload("DND_SCENE_NODE", @ptrCast(*const c_void, &node), @sizeOf(*SceneNode), nc.ImGuiCond_Once);
            nc.igEndDragDropSource();
        }

        // parent_insert prevents reacting to insert action second time
        // even though payload will be set to null, it will be set to undelivered state
        // preventing unloading payload for insert action
        if (self.parent_insert == null and nc.igBeginDragDropTarget()) {
            const payload: ?*const nc.ImGuiPayload = nc.igAcceptDragDropPayload("DND_SCENE_NODE", 0);
            if (payload) |p| {
                self.drag_from = @ptrCast(**SceneNode, @alignCast(@alignOf(**SceneNode), p.Data)).*;
                self.drop_to = node;
            }
            nc.igEndDragDropTarget();
        }
    }

    fn sceneNodeReorderBlock(self: *SceneTree, parent: *SceneNode, after_index: usize) void {
        const payload: ?*const nc.ImGuiPayload = nc.igAcceptReorderDropPayload("DND_SCENE_NODE", 0);
        if (payload) |p| {
            self.drag_from = @ptrCast(**SceneNode, @alignCast(@alignOf(**SceneNode), p.Data)).*;
            self.parent_insert = parent;
            self.parent_insert_index = after_index + 1;
        }
    }
};
