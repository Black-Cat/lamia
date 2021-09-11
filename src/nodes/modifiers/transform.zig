usingnamespace @import("../node_utils.zig");

const nm = @import("nyancore").Math;

pub const Transform: NodeType = .{
    .name = "Transform",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,

    .has_edit_callback = true,
    .edit_callback = editCallback,
};

const Data = struct {
    rotation: nm.vec3,
    translation: nm.vec3,
    transform_matrix: nm.mat4x4,
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

    data.rotation = nm.Vec3.zeros();
    data.translation = nm.Vec3.zeros();
    data.transform_matrix = nm.Mat4x4.identity();

    buffer.* = std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.transform_matrix = nm.Mat4x4.identity();
    nm.Transform.rotateX(&data.transform_matrix, -data.rotation[0]);
    nm.Transform.rotateY(&data.transform_matrix, -data.rotation[1]);
    nm.Transform.rotateZ(&data.transform_matrix, -data.rotation[2]);
    nm.Transform.translate(&data.transform_matrix, -data.translation);
}
