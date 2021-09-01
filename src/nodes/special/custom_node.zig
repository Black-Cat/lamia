usingnamespace @import("../node_utils.zig");

pub const CustomNode: NodeType = .{
    .name = "Custom Node",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    enter_function: [1024]u8,
    exit_function: [1024]u8,

    enter_stack: i32,
    enter_index: i32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    setBuffer(data.enter_function[0..], "cpout = cpin;");
    setBuffer(data.exit_function[0..], "cdout = cdin;");

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
