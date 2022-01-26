const util = @import("../node_utils.zig");

const info = util.nsdf.Transform.info;

pub const Transform: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,

    .has_edit_callback = true,
    .edit_callback = editCallback,

    .modifyGizmoPointsFn = modifyGizmoPoints,
};

const Data = util.nsdf.Transform.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "rotation"),
        .name = "Rotation",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "translation"),
        .name = "Translation",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.rotation = util.nm.Vec3.zeros();
    data.translation = util.nm.Vec3.zeros();
    data.transform_matrix = util.nm.Mat4x4.identity();

    buffer.* = util.std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.transform_matrix = util.nm.Mat4x4.identity();
    util.nm.Transform.rotateX(&data.transform_matrix, -data.rotation[0]);
    util.nm.Transform.rotateY(&data.transform_matrix, -data.rotation[1]);
    util.nm.Transform.rotateZ(&data.transform_matrix, -data.rotation[2]);
    util.nm.Transform.translate(&data.transform_matrix, -data.translation);
}

fn modifyGizmoPoints(buffer: *[]u8, points: []util.nm.vec4) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const inv: util.nm.mat4x4 = util.nm.Mat4x4.inverse(data.transform_matrix);

    for (points) |*p|
        p.* = util.nm.Mat4x4.mulv(inv, p.*);
}
