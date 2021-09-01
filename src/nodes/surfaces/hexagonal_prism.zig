usingnamespace @import("../node_utils.zig");

pub const HexagonalPrism: NodeType = .{
    .name = "Hexagonal Prism",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    height: [2]f32,

    enter_index: i32,
    enter_stack: i32,
    mat: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.height = [_]f32{ 0.5, 1.0 };
    data.mat = 0;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
