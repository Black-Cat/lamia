const util = @import("../node_utils.zig");

const info = util.nsdf.Torus.info;

pub const Torus: util.NodeType = .{
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

const Data = util.nsdf.Torus.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "inner_radius"),
        .name = "Inner Radius",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "outer_radius"),
        .name = "Outer Radius",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.inner_radius = 0.4;
    data.outer_radius = 0.1;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var gizmo: util.SizeGizmo = .{
        .size = &data.inner_radius,
        .offset_dist = null,
        .offset_type = .direction,
        .direction_type = .static,
        .dir = .{ 1.0, 0.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
        .offset_dir = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.outer_radius;
    gizmo.offset_dist = &data.inner_radius;
    gizmo.offset_dir = gizmo.dir;
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.offset_dir = util.nm.Vec3.negate(gizmo.offset_dir);
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
