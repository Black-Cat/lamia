const nyan = @import("nyancore");
const std = @import("std");

pub const SceneNode = struct {
    pub const NAME_SIZE: i32 = 128;

    name: [NAME_SIZE]u8,

    children: std.ArrayList(*SceneNode),

    pub fn init(self: *SceneNode, name: []const u8) void {
        self.children = std.ArrayList(*SceneNode).init(nyan.app.allocator);
        self.setName(name);
    }

    pub fn deinit(self: *SceneNode) void {
        for (self.children) |child|
            child.deinit();
        self.children.deinit();
    }

    pub fn setName(self: *SceneNode, name: []const u8) void {
        @memcpy(@ptrCast([*]u8, &self.name[0]), name.ptr, name.len + 1);
    }

    pub fn add(self: *SceneNode) *SceneNode {
        const new_node: **SceneNode = self.children.addOne() catch unreachable;
        new_node.* = nyan.app.allocator.create(SceneNode) catch unreachable;
        new_node.*.init("New Node");
        return new_node.*;
    }

    pub fn childrenCount(self: *SceneNode) usize {
        return self.children.items.len;
    }
};
