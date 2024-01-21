const util = @import("../node_utils.zig");

const info = util.nsdf.Subtraction.info;

pub const Subtraction: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .deinit_fn = util.defaultDeinit(Data),
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .sphere_bound_fn = info.sphere_bound_fn,

    .min_child_count = 2,
    .max_child_count = util.std.math.maxInt(usize),
};

const Data = util.nsdf.Subtraction.Data;

const properties = [_]util.NodeProperty{};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    buffer.* = util.std.mem.asBytes(data);
}
