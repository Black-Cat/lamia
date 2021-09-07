usingnamespace @import("../node_utils.zig");

pub const FiniteRepetition: NodeType = .{
    .name = "Finite Repetition",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    period: f32,
    size: [3]f32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "period"),
        .name = "Period",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "size"),
        .name = "Size",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.period = 0.5;
    data.size = [_]f32{ 3.0, 3.0, 3.0 };

    buffer.* = std.mem.asBytes(data);
}
