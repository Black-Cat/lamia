const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;
const Scene = @import("../../scene/scene.zig").Scene;
const SceneNode = @import("../../scene/scene_node.zig").SceneNode;
const Global = @import("../../global.zig");

const NodeCollection = @import("../../nodes/node_collection.zig");
const NodeType = @import("../../nodes/node_type.zig").NodeType;

const scene_tree_key_open: []const u8 = "ui_widgets_scene_tree_open";

pub const SceneTree = struct {
    const FILE_PATH_LEN = 256;

    window: nyan.Widgets.Window,

    selected_scene_node: *?*SceneNode,
    clicked_node: ?*SceneNode,

    drag_from: ?*SceneNode,
    drop_to: ?*SceneNode,
    parent_insert: ?*SceneNode,
    parent_insert_index: usize,

    selected_file_path: [FILE_PATH_LEN]u8,

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
        self.cleanSelectedPath();
    }

    pub fn deinit(self: *SceneTree) void {
        _ = self;
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);
        const open: bool = std.mem.eql(u8, nyan.app.config.map.get(scene_tree_key_open) orelse "1", "1");
        self.window.open = open;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);
        nyan.app.config.map.put(scene_tree_key_open, if (self.window.open) "1" else "0") catch unreachable;
    }

    fn drawNodeCollection(collection: []const NodeType, selected_node: *?*SceneNode) void {
        for (collection) |*node_type|
            if (nc.igSelectable_Bool(node_type.name.ptr, false, nc.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 }))
                addNode(node_type, selected_node);
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *SceneTree = @fieldParentPtr(SceneTree, "window", window);

        if (!window.open)
            return;

        _ = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);
        if (nc.igButton("Add Node", .{ .x = 0, .y = 0 }))
            nc.igOpenPopup("add_node_popup", nc.ImGuiPopupFlags_None);

        nc.igSameLine(0.0, 10.0);
        if (nc.igButton("Save", .{ .x = 0, .y = 0 })) {
            self.cleanSelectedPath();
            nc.igOpenPopup("save_scene_popup", nc.ImGuiPopupFlags_None);
        }

        nc.igSameLine(0.0, 10.0);
        if (nc.igButton("Load", .{ .x = 0, .y = 0 })) {
            self.cleanSelectedPath();
            nc.igOpenPopup("load_scene_popup", nc.ImGuiPopupFlags_None);
        }

        self.drawSceneHeirarchy();
        self.drawSceneSettings();

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

            drawNodeCollection(NodeCollection.surfaces[0..], self.selected_scene_node);
            nc.igNextColumn();
            drawNodeCollection(NodeCollection.modifiers[0..], self.selected_scene_node);
            nc.igNextColumn();
            drawNodeCollection(NodeCollection.combinators[0..], self.selected_scene_node);
            nc.igNextColumn();
            drawNodeCollection(NodeCollection.special[0..], self.selected_scene_node);

            nc.igColumns(1, null, true);
            nc.igSetCursorPosX(600);
            nc.igEndPopup();
        }

        var open_modal: bool = true;
        if (nc.igBeginPopupModal("save_scene_popup", &open_modal, nc.ImGuiWindowFlags_None)) {
            if (nc.igInputText("Path", @ptrCast([*c]u8, &self.selected_file_path), FILE_PATH_LEN, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
                self.saveScene();
                nc.igCloseCurrentPopup();
            }
            if (nc.igButton("Save", .{ .x = 0, .y = 0 })) {
                self.saveScene();
                nc.igCloseCurrentPopup();
            }
            nc.igSameLine(200.0, 2.0);
            if (nc.igButton("Cancel", .{ .x = 0, .y = 0 }))
                nc.igCloseCurrentPopup();
            nc.igEndPopup();
        }
        if (nc.igBeginPopupModal("load_scene_popup", &open_modal, nc.ImGuiWindowFlags_None)) {
            if (nc.igInputText("Path", @ptrCast([*c]u8, &self.selected_file_path), FILE_PATH_LEN, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
                self.loadScene();
                nc.igCloseCurrentPopup();
            }
            if (nc.igButton("Load", .{ .x = 0, .y = 0 })) {
                self.loadScene();
                nc.igCloseCurrentPopup();
            }
            nc.igSameLine(200.0, 2.0);
            if (nc.igButton("Cancel", .{ .x = 0, .y = 0 }))
                nc.igCloseCurrentPopup();
            nc.igEndPopup();
        }

        nc.igEnd();
    }

    fn addNode(node_type: *const NodeType, selected_node: *?*SceneNode) void {
        const parent: *SceneNode = if (selected_node.*) |n| n else &Global.main_scene.root;
        var node: *SceneNode = parent.add();
        node.init(node_type, node_type.name, parent);
        Global.main_scene.recompile();
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

    fn drawWarning() void {
        nc.igPushStyleColor_U32(nc.ImGuiCol_Text, 0xff007bff);
        nc.igText("<!>");
        nc.igPopStyleColor(1);

        if (nc.igIsItemHovered(nc.ImGuiHoveredFlags_None)) {
            nc.igBeginTooltip();
            nc.igText("Node exceeds max child count for parent and won't be used in shader");
            nc.igEndTooltip();
        }
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

                if (node.children.items.len - i > node.node_type.max_child_count) {
                    nc.igSameLine(0.0, -1.0);
                    drawWarning();
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

            if (node.children.items.len - i > node.node_type.max_child_count) {
                nc.igSameLine(0.0, -1.0);
                drawWarning();
            }
        }
        self.sceneNodeReorderBlock(node, node.childrenCount());
    }

    fn drawSceneHeirarchy(self: *SceneTree) void {
        if (Global.main_scene.root.childrenCount() == 0) {
            nc.igText("Empty Scene");
            return;
        }

        self.clicked_node = null;

        self.drawSceneNodeChildren(&Global.main_scene.root);

        if (self.drop_to) |drop_to| {
            var drag_from: *SceneNode = self.drag_from.?;
            if (!drop_to.hasParent(drag_from))
                drag_from.reparent(drop_to);

            self.drag_from = null;
            self.drop_to = null;

            Global.main_scene.recompile();
        }

        if (self.parent_insert) |parent_insert| {
            var drag_from: *SceneNode = self.drag_from.?;

            if (!parent_insert.hasParent(drag_from))
                drag_from.reorder(parent_insert, self.parent_insert_index);

            self.drag_from = null;
            self.parent_insert = null;

            Global.main_scene.recompile();
        }

        if (self.clicked_node != null)
            self.selected_scene_node.* = self.clicked_node;
    }

    fn drawSceneSettings(self: *SceneTree) void {
        for (Global.main_scene.settings.children.items) |node| {
            if (nc.igButton(&node.name, .{ .x = 0, .y = 0 }))
                self.selected_scene_node.* = node;
        }
    }

    fn sceneNodeDragDrop(self: *SceneTree, node: *SceneNode) void {
        if (nc.igBeginDragDropSource(nc.ImGuiDragDropFlags_SourceNoDisableHover | nc.ImGuiDragDropFlags_SourceNoHoldToOpenOthers)) {
            nc.igText("Moving \"%s\"", node.name);
            _ = nc.igSetDragDropPayload("DND_SCENE_NODE", @ptrCast(*const anyopaque, &node), @sizeOf(*SceneNode), nc.ImGuiCond_Once);
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

    fn cleanSelectedPath(self: *SceneTree) void {
        @memcpy(@ptrCast([*]u8, &self.selected_file_path[0]), "", 1);
    }

    fn saveScene(self: *SceneTree) void {
        Global.main_scene.save(std.mem.sliceTo(&self.selected_file_path, 0)) catch {
            nyan.printError("Scene", "Error while saving scene");
        };
    }

    fn loadScene(self: *SceneTree) void {
        self.selected_scene_node.* = null;
        Global.main_scene.load(std.mem.sliceTo(&self.selected_file_path, 0)) catch {
            nyan.printError("Scene", "Error while loading scene");
        };
        Global.main_scene.recompile();
    }
};
