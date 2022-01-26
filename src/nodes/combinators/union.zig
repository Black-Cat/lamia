const util = @import("../node_utils.zig");

const info = util.nsdf.Union.info;

pub const Union: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,

    .maxChildCount = util.std.math.maxInt(usize),
};

const Data = util.nsdf.Union.Data;

const properties = [_]util.NodeProperty{};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    buffer.* = util.std.mem.asBytes(data);
}
