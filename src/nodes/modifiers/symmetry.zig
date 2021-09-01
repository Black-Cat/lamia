usingnamespace @import("../node_utils.zig");

pub const Symmetry: NodeType = .{
    .name = "Symmetry",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    axis: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.axis = 1;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
