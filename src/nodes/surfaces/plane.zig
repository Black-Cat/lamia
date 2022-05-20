const util = @import("../node_utils.zig");

const info = util.nsdf.Plane.info;

pub const Plane: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
};

const Data = util.nsdf.Plane.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "normal"),
        .name = "Normal",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "offset"),
        .name = "Offset",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.normal = [_]f32{ 0.0, 1.0, 0.0 };
    data.offset = 0.0;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}
