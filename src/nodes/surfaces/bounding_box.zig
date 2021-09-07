usingnamespace @import("../node_utils.zig");

pub const BoundingBox: NodeType = .{
    .name = "Bounding Box",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    size: [3]f32,
    extent: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "size"),
        .name = "Size",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "extent"),
        .name = "Extent",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.size = [_]f32{ 1.0, 1.0, 1.0 };
    data.extent = 0.1;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
