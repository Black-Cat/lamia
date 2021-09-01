usingnamespace @import("../node_utils.zig");

pub const RoundedCylinder: NodeType = .{
    .name = "Rounded Cylinder",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    diameter: f32,
    rounding_radius: f32,
    height: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.diameter = 1.0;
    data.rounding_radius = 0.1;
    data.height = 0.5;
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
