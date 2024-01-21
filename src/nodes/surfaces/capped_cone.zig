const util = @import("../node_utils.zig");

const info = util.nsdf.CappedCone.info;

pub const CappedCone: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .deinit_fn = util.defaultDeinit(Data),
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .sphere_bound_fn = info.sphere_bound_fn,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.CappedCone.Data;

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
        .offset = @offsetOf(Data, "start_radius"),
        .name = "Start Radius",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "end_radius"),
        .name = "End Radius",
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
    data.start_radius = 1.0;
    data.end_radius = 0.4;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.start, .editCallback = null }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.end, .editCallback = null }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.start_radius,
        .offset_pos = &data.start,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.end_radius,
        .offset_pos = &data.end,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;
}
