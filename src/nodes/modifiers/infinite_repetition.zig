const util = @import("../node_utils.zig");

const info = util.nsdf.InfiniteRepetition.info;

pub const InfiniteRepetition: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
};

const Data = util.nsdf.InfiniteRepetition.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "period"),
        .name = "Period",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.period = 2.0;

    buffer.* = util.std.mem.asBytes(data);
}
