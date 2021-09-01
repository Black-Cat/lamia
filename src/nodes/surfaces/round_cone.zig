usingnamespace @import("../node_utils.zig");

pub const RoundCone: NodeType = .{
    .name = "Round Cone",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    start: [3]f32,
    end: [3]f32,
    start_radius: f32,
    end_radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.start = [_]f32{ 0.0, 0.0, 0.0 };
    data.end = [_]f32{ 1.0, 1.0, 1.0 };
    data.start_radius = 1.0;
    data.end_radius = 0.4;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
