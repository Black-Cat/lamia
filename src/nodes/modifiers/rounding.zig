usingnamespace @import("../node_utils.zig");

pub const Rounding: NodeType = .{
    .name = "Rounding",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.radius = 0.2;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
