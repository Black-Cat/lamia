usingnamespace @import("../node_utils.zig");

pub const Symmetry: NodeType = .{
    .name = "Symmetry",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    axis: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.axis = 1;

    buffer.* = std.mem.asBytes(data);
}
