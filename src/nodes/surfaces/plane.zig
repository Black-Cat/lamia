usingnamespace @import("../node_utils.zig");

pub const Plane: NodeType = .{
    .name = "Plane",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    normal: [3]f32,
    offset: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.normal = [_]f32{ 0.0, 1.0, 0.0 };
    data.offset = 0.0;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
