const util = @import("../node_utils.zig");

const info = util.nsdf.TriangularPrism.info;

pub const TriangularPrism: util.NodeType = .{
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

const Data = util.nsdf.TriangularPrism.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height_horizontal"),
        .name = "Horizontal Height",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height_vertical"),
        .name = "Vertical Height",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.height_horizontal = 0.5;
    data.height_vertical = 1.0;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    var gizmo: util.SizeGizmo = .{
        .size = &data.height_horizontal,
        .offset_dist = null,
        .offset_type = .direction,
        .direction_type = .static,
        .dir = .{ 0.0, 1.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
        .offset_dir = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.height_vertical;
    gizmo.dir = .{ 0.0, 0.0, 1.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
