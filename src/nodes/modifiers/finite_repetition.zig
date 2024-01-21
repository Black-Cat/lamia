const util = @import("../node_utils.zig");

const info = util.nsdf.FiniteRepetition.info;

pub const FiniteRepetition: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .deinit_fn = util.defaultDeinit(Data),
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 1,
};

const Data = util.nsdf.FiniteRepetition.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "period"),
        .name = "Period",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "size"),
        .name = "Size",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.period = 2.0;
    data.size = [_]f32{ 3.0, 3.0, 3.0 };

    buffer.* = util.std.mem.asBytes(data);
}
