usingnamespace @import("../node_utils.zig");

pub const VerticalCappedCylinder: NodeType = .{
    .name = "Vertical Capped Cylinder",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    height: f32,
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.height = 1.0;
    data.radius = 0.5;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
