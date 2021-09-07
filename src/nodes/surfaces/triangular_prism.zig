usingnamespace @import("../node_utils.zig");

pub const TriangularPrism: NodeType = .{
    .name = "Triangular Prism",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    height_horizontal: f32,
    height_vertical: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "height_horizontal"),
        .name = "Horizontal Height",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "height_vertical"),
        .name = "Vertical Height",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.height_horizontal = 0.5;
    data.height_vertical = 1.0;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
