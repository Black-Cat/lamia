const util = @import("../node_utils.zig");

const info = util.nsdf.RoundBox.info;

pub const RoundBox: util.NodeType = .{
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

const Data = util.nsdf.RoundBox.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "size"),
        .name = "Size",
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

    data.size = [_]f32{ 1.0, 1.0, 1.0 };
    data.radius = 0.1;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const gizmo: util.SizeGizmo = .{
            .size = &data.size[i],
            .dir = .{
                @intToFloat(f32, @boolToInt(i == 0)),
                @intToFloat(f32, @boolToInt(i == 1)),
                @intToFloat(f32, @boolToInt(i == 2)),
            },
            .offset_dist = null,
            .offset_type = .direction,
            .direction_type = .static,

            .dir_points = undefined,
            .offset_dir = undefined,
            .offset_pos = undefined,
        };
        gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
    }
}
