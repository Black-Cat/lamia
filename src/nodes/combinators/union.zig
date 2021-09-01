usingnamespace @import("../node_utils.zig");

pub const Union: NodeType = .{
    .name = "Union",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    enter_index: i32,
    enter_stack: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    buffer.* = std.mem.asBytes(data);
}
