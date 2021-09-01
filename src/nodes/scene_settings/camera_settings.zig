usingnamespace @import("../node_utils.zig");

pub const CameraSettings: NodeType = .{
    .name = "Camera Settings",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    near: f32,
    far: f32,
    fov: f32,
    steps: u32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.near = 0.1;
    data.far = 10.0;
    data.fov = 60.0;
    data.steps = 64;

    buffer.* = std.mem.asBytes(data);
}
