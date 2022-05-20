const util = @import("../node_utils.zig");

const info = util.nsdf.Symmetry.info;

pub const Symmetry: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 1,
};

const Data = util.nsdf.Symmetry.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawAxisMaskProperty,
        .offset = @offsetOf(Data, "axis"),
        .name = "Axis",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.axis = 1;

    buffer.* = util.std.mem.asBytes(data);
}
