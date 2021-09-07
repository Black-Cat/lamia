usingnamespace @import("../node_utils.zig");

pub const Rounding: NodeType = .{
    .name = "Rounding",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "radius"),
        .name = "Radius",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.radius = 0.2;

    buffer.* = std.mem.asBytes(data);
}
