const util = @import("../node_utils.zig");

const info = util.nsdf.Icosahedron.info;

pub const Icosahedron: util.NodeType = .{
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

const Data = util.nsdf.Icosahedron.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "radius"),
        .name = "Radius",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "corner_radius"),
        .name = "Corner Radius",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.radius = 1.0;
    data.corner_radius = 0.1;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    _ = buffer;
    _ = gizmos_storage;
}
