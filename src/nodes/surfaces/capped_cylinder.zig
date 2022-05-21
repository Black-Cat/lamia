const util = @import("../node_utils.zig");

const info = util.nsdf.CappedCylinder.info;

pub const CappedCylinder: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .sphere_bound_fn = info.sphere_bound_fn,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.CappedCylinder.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "start"),
        .name = "Start",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "end"),
        .name = "End",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "radius"),
        .name = "Radius",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.start = .{ 0.0, 0.0, 0.0 };
    data.end = .{ 1.0, 1.0, 1.0 };
    data.radius = 0.5;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.start, .editCallback = null }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.end, .editCallback = null }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.radius,
        .offset_pos = &data.start,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.radius,
        .offset_pos = &data.end,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;
}
