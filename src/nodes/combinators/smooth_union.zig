const util = @import("../node_utils.zig");

const info = util.nsdf.SmoothUnion.info;

pub const SmoothUnion: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .deinit_fn = util.defaultDeinit(Data),
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .append_mat_check_fn = info.append_mat_check_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 1,
    .max_child_count = 2,
};

const Data = util.nsdf.SmoothUnion.Data;

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
