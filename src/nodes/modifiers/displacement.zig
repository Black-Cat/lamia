usingnamespace @import("../node_utils.zig");

pub const Displacement: NodeType = .{
    .name = "Displacement",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    power: f32,

    enter_index: i32,
    enter_stack: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "power"),
        .name = "Power",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.power = 20.0;

    buffer.* = std.mem.asBytes(data);
}
