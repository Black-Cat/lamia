const std = @import("std");
const SceneNode = @import("scene_node.zig").SceneNode;
const NodeType = @import("../nodes/node_type.zig").NodeType;

fn root_init(buffer: *[]u8) void {}

const RootType: NodeType = .{
    .name = "root",
    .function_defenition = "",

    .init_data_fn = root_init,
};

pub const Scene = struct {
    root: SceneNode,

    pub fn init(self: *Scene) void {
        self.root.init(&RootType, "Root", null);
    }
    pub fn deinit(self: *Scene) void {
        self.root.deinit();
    }

    fn writeU32(file: *const std.fs.File, val_usize: usize) std.os.WriteError!void {
        const val_u32: u32 = @intCast(u32, val_usize);
        var temp: [@sizeOf(u32)]u8 = undefined;
        std.mem.writeIntBig(u32, &temp, val_u32);
        try file.writeAll(temp[0..]);
    }

    fn recursiveSave(node: *SceneNode, file: *const std.fs.File) std.os.WriteError!void {
        const name: []const u8 = std.mem.sliceTo(&node.name, 0);

        try writeU32(file, name.len);
        try file.writeAll(name);

        try writeU32(file, node.node_type.name.len);
        try file.writeAll(node.node_type.name);

        try writeU32(file, node.buffer.len);
        try file.writeAll(node.buffer);

        try writeU32(file, node.childrenCount());
        for (node.children.items) |child|
            try recursiveSave(child, file);
    }

    pub fn save(self: *Scene, path: []const u8) !void {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = try cwd.createFile(path, .{ .read = true, .truncate = true });
        defer file.close();

        try writeU32(&file, self.root.childrenCount());
        for (self.root.children.items) |child|
            try recursiveSave(child, &file);
    }

    // Doesn't recompile shaders!!!
    pub fn load(self: *Scene, path: []const u8) !void {
        const mode: std.os.mode_t = if (std.Target.current.os.tag == .windows) 0 else 0o666;
        var file: std.os.fd_t = try std.os.open(path, std.os.O_RDONLY, mode);
        defer std.os.close(file);
    }
};
