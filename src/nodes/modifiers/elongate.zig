usingnamespace @import("../node_utils.zig");

pub const Elongate: NodeType = .{
    .name = "Elongate",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    height: f32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.height = 2.0;

    buffer.* = std.mem.asBytes(data);
}
