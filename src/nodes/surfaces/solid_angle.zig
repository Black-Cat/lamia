const util = @import("../node_utils.zig");

const info = util.nsdf.SolidAngle.info;

pub const SolidAngle: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.SolidAngle.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "angle"),
        .name = "Angle",
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

    data.angle = 0.523599;
    data.radius = 0.5;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.size_gizmos.append(.{
        .size = &data.radius,
        .offset_type = .direction,
        .direction_type = .static,
        .offset_dist = null,
        .dir = .{ 0.0, 1.0, 0.0 },

        .offset_dir = undefined,
        .offset_pos = undefined,
        .dir_points = undefined,
    }) catch unreachable;
}
