const nyan = @import("nyancore");
const std = @import("std");
const NodeType = @import("../nodes/node_type.zig").NodeType;

pub const SceneNode = struct {
    pub const NAME_SIZE: i32 = 128;

    name: [NAME_SIZE]u8,
    node_type: *const NodeType,

    buffer: []u8,

    children: std.ArrayList(*SceneNode),
    parent: ?*SceneNode,

    pub fn init(self: *SceneNode, node_type: *const NodeType, name: []const u8, parent: ?*SceneNode) void {
        self.initWithoutName(node_type, parent);

        self.setName(name);
    }

    pub fn initWithoutName(self: *SceneNode, node_type: *const NodeType, parent: ?*SceneNode) void {
        self.children = std.ArrayList(*SceneNode).init(nyan.app.allocator);
        self.node_type = node_type;
        self.parent = parent;

        self.node_type.init_data_fn(&self.buffer);
    }

    pub fn deinit(self: *SceneNode) void {
        for (self.children.items) |child|
            child.deinit();
        self.children.deinit();

        nyan.app.allocator.free(self.buffer);
    }

    pub fn setName(self: *SceneNode, name: []const u8) void {
        @memcpy(@ptrCast([*]u8, &self.name[0]), name.ptr, name.len + 1);
    }

    pub fn add(self: *SceneNode) *SceneNode {
        const new_node: **SceneNode = self.children.addOne() catch unreachable;
        new_node.* = nyan.app.allocator.create(SceneNode) catch unreachable;
        return new_node.*;
    }

    fn addExisting(self: *SceneNode, node: *SceneNode) void {
        const new_node: **SceneNode = self.children.addOne() catch unreachable;
        new_node.* = node;
    }

    fn removeChild(self: *SceneNode, node: *SceneNode) usize {
        const ind: usize = for (self.children.items) |child, i| {
            if (child == node) break i;
        } else unreachable;
        _ = self.children.orderedRemove(ind);
        return ind;
    }

    pub fn childrenCount(self: *SceneNode) usize {
        return self.children.items.len;
    }

    pub fn hasParent(self: *SceneNode, test_parent: *SceneNode) bool {
        var cur_parent: ?*SceneNode = self;
        while (cur_parent) |p| {
            if (p == test_parent)
                return true;
            cur_parent = p.parent;
        }

        return false;
    }

    pub fn reparent(self: *SceneNode, new_parent: *SceneNode) void {
        const old_parent: *SceneNode = self.parent.?;
        self.parent = new_parent;

        new_parent.addExisting(self);
        _ = old_parent.removeChild(self);
    }
    pub fn reorder(self: *SceneNode, new_parent: *SceneNode, insert_index: usize) void {
        const old_parent: *SceneNode = self.parent.?;
        self.parent = new_parent;

        const ind: usize = old_parent.removeChild(self);

        const ins_pos: usize = if (new_parent == old_parent and ind < insert_index)
            insert_index - 1
        else
            insert_index;

        new_parent.children.insert(ins_pos - 1, self) catch unreachable;
    }
};
