usingnamespace @import("../node_utils.zig");

pub const Onion: NodeType = .{
    .name = "Onion",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    thickness: f32,

    enter_index: i32,
    enter_stack: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.thickness = 0.2;

    buffer.* = std.mem.asBytes(data);
}
