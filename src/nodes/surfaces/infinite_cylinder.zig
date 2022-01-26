const util = @import("../node_utils.zig");

const info = util.nsdf.InfiniteCylinder.info;

pub const InfiniteCylinder: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
};

const Data = util.nsdf.InfiniteCylinder.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "direction"),
        .name = "Direction",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.direction = [_]f32{ 0.5, 0.5, 0.5 };
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}
