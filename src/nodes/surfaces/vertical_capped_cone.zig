usingnamespace @import("../node_utils.zig");

pub const VerticalCappedCone: NodeType = .{
    .name = "Vertical Capped Cone",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    height: f32,
    start_radius: f32,
    end_radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.height = 1.0;
    data.start_radius = 1.0;
    data.end_radius = 0.4;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}
