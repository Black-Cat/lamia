const util = @import("../node_utils.zig");

const info = util.nsdf.Twist.info;

pub const Twist: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 1,
};

const Data = util.nsdf.Twist.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "power"),
        .name = "Power",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.power = 1.0;

    buffer.* = util.std.mem.asBytes(data);
}
