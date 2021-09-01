usingnamespace @import("../node_utils.zig");

pub const SmoothIntersection: NodeType = .{
    .name = "Smooth Intersection",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    smoothing: f32,

    enter_index: i32,
    enter_stack: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.smoothing = 0.5;

    buffer.* = std.mem.asBytes(data);
}
