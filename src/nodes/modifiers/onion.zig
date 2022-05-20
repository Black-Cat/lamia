const util = @import("../node_utils.zig");

const info = util.nsdf.Onion.info;

pub const Onion: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 1,
};

const Data = util.nsdf.Onion.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "thickness"),
        .name = "Thickness",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.thickness = 0.2;

    buffer.* = util.std.mem.asBytes(data);
}
