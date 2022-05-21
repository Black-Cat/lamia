const util = @import("../node_utils.zig");

const info = util.nsdf.Transform.info;

pub const Transform: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 1,

    .has_edit_callback = true,
    .edit_callback = editCallback,

    .appendGizmosFn = appendGizmos,
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

    buffer.* = util.std.mem.asBytes(data);

    util.nsdf.Transform.initZero(buffer);
}

fn editCallback(buffer: *[]u8) void {
    util.nsdf.Transform.updateMatrix(buffer);
}

fn gizmoEditCallback(pos: *util.nm.vec3) void {
    var data: *Data = @fieldParentPtr(Data, "translation", pos);
    editCallback(@ptrCast(*[]u8, &data));
}

fn modifyGizmoPoints(buffer: *[]u8, points: []util.nm.vec4) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const inv: util.nm.mat4x4 = util.nm.Mat4x4.inverse(data.transform_matrix);

    for (points) |*p|
        p.* = util.nm.Mat4x4.mulv(inv, p.*);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.translation, .editCallback = gizmoEditCallback }) catch unreachable;
}
