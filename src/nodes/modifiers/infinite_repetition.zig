usingnamespace @import("../node_utils.zig");

pub const InfiniteRepetition: NodeType = .{
    .name = "Infinite Repetition",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    period: f32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.period = 0.5;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
