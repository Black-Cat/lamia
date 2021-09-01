usingnamespace @import("../node_utils.zig");

pub const BoundingBox: NodeType = .{
    .name = "Bounding Box",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    size: [3]f32,
    extent: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.size = [_]f32{ 1.0, 1.0, 1.0 };
    data.extent = 0.1;
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
