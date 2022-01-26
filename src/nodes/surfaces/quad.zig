const util = @import("../node_utils.zig");

const info = util.nsdf.Quad.info;

pub const Quad: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.Quad.Data;

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
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "point_d"),
        .name = "Point D",
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
    data.point_b = .{ 0.0, 1.0, 0.0 };
    data.point_c = .{ 1.0, 1.0, 0.0 };
    data.point_d = .{ 1.0, 0.0, 0.0 };
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_a }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_b }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_c }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_d }) catch unreachable;
}
