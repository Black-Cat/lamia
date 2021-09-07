usingnamespace @import("../node_utils.zig");

pub const FileSceneNode: NodeType = .{
    .name = "File Scene Node",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,

    .has_edit_callback = true,
    .edit_callback = editCallback,
};

const Data = struct {
    const max_path_len: usize = 256;
    file_path: [max_path_len]u8,
    last_path: [max_path_len]u8,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawTextProperty,
        .offset = @byteOffsetOf(Data, "file_path"),
        .name = "Path",
        .prop_len = Data.max_path_len,
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    setBuffer(data.file_path[0..], "");
    setBuffer(data.last_path[0..], "");

    buffer.* = std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    @panic("Not implemented =c");
}
