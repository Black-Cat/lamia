usingnamespace @import("../node_utils.zig");

pub const Rhombus: NodeType = .{
    .name = "Rhombus",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    length_horizontal: f32,
    length_vertical: f32,
    height: f32,
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "length_horizontal"),
        .name = "Horizontal Length",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "length_vertical"),
        .name = "Vertical Length",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "height"),
        .name = "Height",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "radius"),
        .name = "Radius",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.length_horizontal = 1.0;
    data.length_vertical = 0.3;
    data.height = 0.1;
    data.radius = 0.1;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
