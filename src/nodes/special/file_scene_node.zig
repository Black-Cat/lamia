usingnamespace @import("../node_utils.zig");

pub const FileSceneNode: NodeType = .{
    .name = "File Scene Node",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    file_path: [256]u8,
    last_path: [256]u8,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    setBuffer(data.file_path[0..], "");
    setBuffer(data.last_path[0..], "");

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
