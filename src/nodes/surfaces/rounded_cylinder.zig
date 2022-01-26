const util = @import("../node_utils.zig");

const info = util.nsdf.RoundedCylinder.info;

pub const RoundedCylinder: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.RoundedCylinder.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "diameter"),
        .name = "Diameter",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "rounding_radius"),
        .name = "Rouning Radius",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height"),
        .name = "Height",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.diameter = 1.0;
    data.rounding_radius = 0.1;
    data.height = 0.5;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var gizmo: util.SizeGizmo = .{
        .size = &data.diameter,
        .offset_type = .direction,
        .direction_type = .static,
        .offset_dist = null,
        .dir = .{ 1.0, 0.0, 0.0 },

        .offset_dir = undefined,
        .offset_pos = undefined,
        .dir_points = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.height;
    gizmo.dir = .{ 0.0, 1.0, 0.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
