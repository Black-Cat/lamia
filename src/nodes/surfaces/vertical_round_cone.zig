usingnamespace @import("../node_utils.zig");

pub const VerticalRoundCone: NodeType = .{
    .name = "Vertical Round Cone",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    start_radius: f32,
    end_radius: f32,
    height: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.start_radius = 0.8;
    data.end_radius = 0.3;
    data.height = 1.0;
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
