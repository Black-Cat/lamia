usingnamespace @import("../node_utils.zig");

pub const Lambert: NodeType = .{
    .name = "Lambert",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    color: [3]f32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.color = [3]f32{ 0.8, 0.8, 0.8 };

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
