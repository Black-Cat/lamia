usingnamespace @import("../node_utils.zig");

pub const InfiniteCylinder: NodeType = .{
    .name = "Infinite Cylinder",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    direction: [3]f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "direction"),
        .name = "Direction",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.direction = [_]f32{ 0.5, 0.5, 0.5 };
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
