usingnamespace @import("../node_utils.zig");

pub const CappedCylinder: NodeType = .{
    .name = "Capped Cylinder",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    start: [3]f32,
    end: [3]f32,
    radius: f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.start = [_]f32{ 0.0, 0.0, 0.0 };
    data.end = [_]f32{ 1.0, 1.0, 1.0 };
    data.radius = 0.5;
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
