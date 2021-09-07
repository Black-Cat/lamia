const std = @import("std");
const nyan = @import("nyancore");
const SceneNode = @import("scene_node.zig").SceneNode;
const NodeType = @import("../nodes/node_type.zig").NodeType;
const NodeProperty = @import("../nodes/node_property.zig").NodeProperty;
const node_collection = @import("../nodes/node_collection.zig");

fn root_init(buffer: *[]u8) void {
    buffer.* = nyan.app.allocator.alloc(u8, 0) catch unreachable;
}

const root_properties = [_]NodeProperty{};

const RootType: NodeType = .{
    .name = "root",
    .function_defenition = "",

    .properties = root_properties[0..],

    .init_data_fn = root_init,
};

pub const Scene = struct {
    root: SceneNode,
    settings: SceneNode,
    materials: SceneNode,

    fn createRoots(self: *Scene) void {
        self.root.init(&RootType, "Root", null);
        self.settings.init(&RootType, "Settings", null);
        self.materials.init(&RootType, "Materials", null);
    }

    pub fn init(self: *Scene) void {
        self.createRoots();

        for (node_collection.scene_settings) |*node_type| {
            var node: *SceneNode = self.settings.add();
            node.init(node_type, node_type.name, &self.settings);
        }

        var default_material: *SceneNode = self.materials.add();
        default_material.init(&node_collection.materials[0], "Default Material", &self.materials);
    }

    pub fn deinit(self: *Scene) void {
        self.materials.deinit();
        self.settings.deinit();
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

        try file.writeAll(node.buffer);

        try writeU32(file, node.childrenCount());
        for (node.children.items) |child|
            try recursiveSave(child, file);
    }

    fn saveRoot(root: *SceneNode, file: *const std.fs.File) std.os.WriteError!void {
        try writeU32(file, root.childrenCount());
        for (root.children.items) |child|
            try recursiveSave(child, file);
    }

    pub fn save(self: *Scene, path: []const u8) !void {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = try cwd.createFile(path, .{ .read = true, .truncate = true });
        defer file.close();

        try saveRoot(&self.root, &file);
        try saveRoot(&self.settings, &file);
        try saveRoot(&self.materials, &file);
    }

    fn readU32(file: *const std.fs.File) std.os.ReadError!usize {
        var temp: [@sizeOf(u32)]u8 = undefined;
        _ = try file.readAll(temp[0..]);
        return @intCast(usize, std.mem.readIntBig(u32, &temp));
    }

    fn recursiveLoad(parent: *SceneNode, file: *const std.fs.File) std.os.ReadError!void {
        var node: *SceneNode = parent.add();

        const name_len: usize = try readU32(file);
        _ = try file.readAll(node.name[0..name_len]);
        node.name[name_len] = 0;

        const node_type_len: usize = try readU32(file);
        var node_type_name: []u8 = nyan.app.allocator.alloc(u8, node_type_len) catch unreachable;
        defer nyan.app.allocator.free(node_type_name);
        _ = try file.readAll(node_type_name);

        const node_type: *const NodeType = node_collection.node_map.get(node_type_name).?;
        node.initWithoutName(node_type, parent);

        _ = try file.readAll(node.buffer);

        var children_count: usize = try readU32(file);
        while (children_count > 0) : (children_count -= 1)
            try recursiveLoad(node, file);
    }

    fn loadRoot(parent: *SceneNode, file: *const std.fs.File) std.os.ReadError!void {
        var root_level_nodes_count: usize = try readU32(file);
        while (root_level_nodes_count > 0) : (root_level_nodes_count -= 1)
            try recursiveLoad(parent, file);
    }

    // Doesn't recompile scene shaders!!!
    pub fn load(self: *Scene, path: []const u8) !void {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = try cwd.openFile(path, .{ .read = true });
        defer file.close();

        self.deinit();
        self.createRoots();

        try loadRoot(&self.root, &file);
        try loadRoot(&self.settings, &file);
        try loadRoot(&self.materials, &file);
    }
};
