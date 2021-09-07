usingnamespace @import("../node_utils.zig");

pub const InfiniteRepetition: NodeType = .{
    .name = "Infinite Repetition",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    period: f32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "period"),
        .name = "Period",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.period = 0.5;

    buffer.* = std.mem.asBytes(data);
}
