const util = @import("../node_utils.zig");

const Global = @import("../../global.zig");
const FileWatcher = @import("../../scene/file_watcher.zig").FileWatcher;

pub const FileSceneNode: util.NodeType = .{
    .name = "File Scene Node",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,

    .has_edit_callback = true,
    .edit_callback = editCallback,

    .has_deinit = true,
    .deinit_fn = deinit,

    .has_on_load = true,
    .on_load_fn = on_load,

    .external = true,
};

pub const Data = struct {
    const max_path_len: usize = 256;
    file_path: [max_path_len]u8,
    last_path: [max_path_len]u8,
};

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawTextProperty,
        .offset = @offsetOf(Data, "file_path"),
        .name = "Path",
        .prop_len = Data.max_path_len,
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    util.setBuffer(data.file_path[0..], "");
    util.setBuffer(data.last_path[0..], "");

    buffer.* = util.std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const last_path_slice: []const u8 = util.std.mem.sliceTo(&data.last_path, 0);
    const file_path_slice: []const u8 = util.std.mem.sliceTo(&data.file_path, 0);

    const fw: *FileWatcher = &Global.file_watcher;
    if (fw.map.getPtr(last_path_slice)) |val|
        val.ref_count -= 1;

    if (!fw.map.contains(file_path_slice))
        _ = fw.addExternFile(file_path_slice);

    if (fw.map.getPtr(file_path_slice)) |val|
        val.ref_count += 1;

    util.std.mem.copy(u8, data.last_path[0..], data.file_path[0..]);
}

fn on_load(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));
    const fw: *FileWatcher = &Global.file_watcher;

    const last_path_slice: []const u8 = util.std.mem.sliceTo(&data.last_path, 0);

    if (!fw.map.contains(last_path_slice))
        _ = fw.addExternFile(last_path_slice);

    if (fw.map.getPtr(last_path_slice)) |val|
        val.ref_count += 1;

    util.std.mem.copy(u8, data.file_path[0..], data.last_path[0..]);
}

fn deinit(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));
    const fw: *FileWatcher = &Global.file_watcher;

    const last_path_slice: []const u8 = util.std.mem.sliceTo(&data.last_path, 0);

    if (fw.map.getPtr(last_path_slice)) |val|
        val.ref_count -= 1;
}
