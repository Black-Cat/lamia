const SceneNode = @import("scene_node.zig").SceneNode;
const NodeType = @import("../nodes/node_type.zig").NodeType;

fn root_init(buffer: **c_void, buffer_size: *usize) void {}

const RootType: NodeType = .{
    .name = "root",
    .function_defenition = "",

    .init_data_fn = root_init,
};

pub const Scene = struct {
    root: SceneNode,

    pub fn init(self: *Scene) void {
        self.root.init(&RootType, "Root", null);
    }
    pub fn deinit(self: *Scene) void {
        self.root.deinit();
    }
};
