const util = @import("../node_utils.zig");

const info = util.nsdf.SmoothSubtraction.info;

pub const SmoothSubtraction: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 2,
    .max_child_count = util.std.math.maxInt(usize),
};

const Data = util.nsdf.SmoothSubtraction.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .name = "Smoothing",
        .offset = @offsetOf(Data, "smoothing"),
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.smoothing = 0.5;

    buffer.* = util.std.mem.asBytes(data);
}
