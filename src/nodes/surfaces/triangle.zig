usingnamespace @import("../node_utils.zig");

pub const Triangle: NodeType = .{
    .name = "Triangle",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    point_a: [3]f32,
    point_b: [3]f32,
    point_c: [3]f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_a"),
        .name = "Point A",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_b"),
        .name = "Point B",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_c"),
        .name = "Point C",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.point_a = [_]f32{ 0.0, 0.0, 0.0 };
    data.point_b = [_]f32{ 0.5, 0.5, 0.0 };
    data.point_c = [_]f32{ 1.0, 0.0, 0.0 };
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
