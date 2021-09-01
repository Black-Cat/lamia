usingnamespace @import("../node_utils.zig");

pub const Scale: NodeType = .{
    .name = "Scale",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    scale: f32,

    enter_index: i32,
    enter_stack: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.scale = 1.0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
