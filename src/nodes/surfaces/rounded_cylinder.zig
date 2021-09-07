usingnamespace @import("../node_utils.zig");

pub const RoundedCylinder: NodeType = .{
    .name = "Rounded Cylinder",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    diameter: f32,
    rounding_radius: f32,
    height: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "diameter"),
        .name = "Diameter",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "rounding_radius"),
        .name = "Rouning Radius",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "height"),
        .name = "Height",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.diameter = 1.0;
    data.rounding_radius = 0.1;
    data.height = 0.5;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
