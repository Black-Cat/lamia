const util = @import("../node_utils.zig");

const info = util.nsdf.VerticalCappedCone.info;

pub const VerticalCappedCone: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.VerticalCappedCone.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height"),
        .name = "Height",
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

    data.height = 1.0;
    data.start_radius = 1.0;
    data.end_radius = 0.4;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var gizmo: util.SizeGizmo = .{
        .size = &data.start_radius,
        .offset_dist = &data.height,
        .offset_type = .direction,
        .direction_type = .static,
        .offset_dir = .{ 0.0, -1.0, 0.0 },
        .dir = .{ 1.0, 0.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.end_radius;
    gizmo.offset_dir = .{ 0.0, 1.0, 0.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.height;
    gizmo.offset_dist = null;
    gizmo.dir = .{ 0.0, 1.0, 0.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
