const util = @import("../node_utils.zig");

const info = util.nsdf.BezierCurve.info;

pub const BezierCurve: util.NodeType = .{
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

const Data = util.nsdf.BezierCurve.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "point_a"),
        .name = "Point A",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "point_b"),
        .name = "Point B",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "point_c"),
        .name = "Point C",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "width_start"),
        .name = "Start Width",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "width_end"),
        .name = "End Width",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.point_a = .{ 0.0, 0.0, 0.0 };
    data.point_b = .{ 2.0, 1.0, 0.0 };
    data.point_c = .{ 3.0, 0.0, 0.0 };
    data.width_start = 0.4;
    data.width_end = 0.0;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_a, .editCallback = null }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_b, .editCallback = null }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_c, .editCallback = null }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.width_start,
        .offset_type = .position,
        .direction_type = .cross,
        .offset_pos = &data.point_a,
        .dir_points = .{ &data.point_a, &data.point_b },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.width_end,
        .offset_type = .position,
        .direction_type = .cross,
        .offset_pos = &data.point_c,
        .dir_points = .{ &data.point_c, &data.point_b },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;
}
