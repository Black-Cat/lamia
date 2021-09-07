usingnamespace @import("../node_utils.zig");

pub const Lambert: NodeType = .{
    .name = "Lambert",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    color: [3]f32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawColor3Property,
        .offset = @byteOffsetOf(Data, "color"),
        .name = "Color",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.color = [3]f32{ 0.8, 0.8, 0.8 };

    buffer.* = std.mem.asBytes(data);
}
