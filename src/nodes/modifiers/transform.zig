usingnamespace @import("../node_utils.zig");

pub const Transform: NodeType = .{
    .name = "Transform",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,

    .has_edit_callback = true,
    .edit_callback = editCallback,
};

const Data = struct {
    rotation: [3]f32,
    translation: [3]f32,
    transform_matrix: [16]f32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "rotation"),
        .name = "Rotation",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "translation"),
        .name = "Translation",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.rotation = [_]f32{ 0.0, 0.0, 0.0 };
    data.translation = [_]f32{ 0.0, 0.0, 0.0 };
    data.transform_matrix = [_]f32{
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 0.0,
    };

    buffer.* = std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    @panic("Not implemented =c");
}
