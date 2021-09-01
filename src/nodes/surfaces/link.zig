usingnamespace @import("../node_utils.zig");

pub const Link: NodeType = .{
    .name = "Link",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    length: f32,
    inner_radius: f32,
    outer_radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.length = 1.0;
    data.inner_radius = 0.4;
    data.outer_radius = 0.1;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
