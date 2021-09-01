usingnamespace @import("../node_utils.zig");

pub const FiniteRepetition: NodeType = .{
    .name = "Finite Repetition",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    period: f32,
    size: [3]f32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.period = 0.5;
    data.size = [_]f32{ 3.0, 3.0, 3.0 };

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
