const SceneNode = @import("scene_node.zig").SceneNode;

pub const Scene = struct {
    root: SceneNode,

    pub fn init(self: *Scene) void {
        self.root.init("Root", null);
    }
    pub fn deinit(self: *Scene) void {
        self.root.deinit();
    }
};
