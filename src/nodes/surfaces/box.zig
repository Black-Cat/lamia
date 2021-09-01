usingnamespace @import("../node_utils.zig");

pub const Box: NodeType = .{
    .name = "Box",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    size: [3]f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.size = [_]f32{ 1.0, 1.0, 1.0 };
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
