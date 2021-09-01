usingnamespace @import("../node_utils.zig");

pub const InfiniteCone: NodeType = .{
    .name = "Infinite Cone",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    angle: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.angle = 0.52;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
