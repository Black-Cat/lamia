usingnamespace @import("../node_utils.zig");

pub const OrenNayar: NodeType = .{
    .name = "Oren Nayar",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    color: [3]f32,
    roughness: f32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawColor3Property,
        .offset = @byteOffsetOf(Data, "color"),
        .name = "Color",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "roughness"),
        .name = "Roughness",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.color = [3]f32{ 0.8, 0.8, 0.8 };
    data.roughness = 1.0;

    buffer.* = std.mem.asBytes(data);
}
