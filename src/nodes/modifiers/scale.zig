usingnamespace @import("../node_utils.zig");

pub const Scale: NodeType = .{
    .name = "Scale",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    scale: f32,

    enter_index: i32,
    enter_stack: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "scale"),
        .name = "Scale",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.scale = 1.0;

    buffer.* = std.mem.asBytes(data);
}
