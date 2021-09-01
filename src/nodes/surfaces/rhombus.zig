usingnamespace @import("../node_utils.zig");

pub const Rhombus: NodeType = .{
    .name = "Rhombus",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    length: [2]f32,
    height: f32,
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.length = [_]f32{ 1.0, 0.3 };
    data.height = 0.1;
    data.radius = 0.1;
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
