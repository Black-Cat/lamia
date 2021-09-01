usingnamespace @import("../node_utils.zig");

pub const InfiniteRepetition: NodeType = .{
    .name = "Infinite Repetition",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    period: f32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.period = 0.5;

    buffer.* = std.mem.asBytes(data);
}
