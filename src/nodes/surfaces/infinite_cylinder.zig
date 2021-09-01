usingnamespace @import("../node_utils.zig");

pub const InfiniteCylinder: NodeType = .{
    .name = "Infinite Cylinder",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    direction: [3]f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.direction = [_]f32{ 0.5, 0.5, 0.5 };
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
