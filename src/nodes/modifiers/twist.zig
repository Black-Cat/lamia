usingnamespace @import("../node_utils.zig");

pub const Twist: NodeType = .{
    .name = "Twist",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    power: f32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.power = 10.0;

    buffer.* = std.mem.asBytes(data);
}
