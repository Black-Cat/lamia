usingnamespace @import("../node_utils.zig");

pub const SolidAngle: NodeType = .{
    .name = "Solid Angle",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    angle: f32,
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "angle"),
        .name = "Angle",
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

    data.angle = 0.523599;
    data.radius = 0.5;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}