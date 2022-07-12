const std = @import("std");
const nyan = @import("nyancore");
const Global = @import("../global.zig");

const SceneNode = @import("scene_node.zig").SceneNode;
const NodeType = @import("../nodes/node_type.zig").NodeType;
const UnionNodeType = @import("../nodes/combinators/union.zig").Union;
const NodeProperty = @import("../nodes/node_property.zig").NodeProperty;
const node_collection = @import("../nodes/node_collection.zig");
const scene2shader = @import("scene2shader.zig").scene2shader;

fn root_init(buffer: *[]u8) void {
    buffer.* = nyan.app.allocator.alloc(u8, 0) catch unreachable;
}

const root_properties = [_]NodeProperty{};

const EndOfStreamError = error{
    EndOfStream,
};

pub const RootType: NodeType = .{
    .name = "root",
    .function_definition = "",

    .properties = root_properties[0..],

    .init_data_fn = root_init,
};

pub const Scene = struct {
    root: SceneNode,
    settings: SceneNode,
    materials: SceneNode,

    camera_settings: *SceneNode,
    environment_settings: *SceneNode,

    shader: ?nyan.ShaderModule,
    rg_resource: nyan.RGResource,

    fn createRoots(self: *Scene) void {
        self.root.init(&UnionNodeType, "Root", null);
        self.settings.init(&RootType, "Settings", null);
        self.materials.init(&RootType, "Materials", null);
    }

    pub fn create_shader_resource(self: *Scene) void {
        self.rg_resource.init("Scene Shader", nyan.app.allocator);
    }

    pub fn init(self: *Scene) void {
        self.createRoots();

        for (node_collection.scene_settings) |*node_type| {
            var node: *SceneNode = self.settings.add();
            node.init(node_type, node_type.name, &self.settings);
        }

        var default_material: *SceneNode = self.materials.add();
        default_material.init(node_collection.node_map.get("Lambert").?, "Default Material", &self.materials);

        self.create_shader_resource();
        self.findSettings();
    }

    pub fn deinit(self: *Scene) void {
        self.shader.?.destroy();

        self.rg_resource.deinit();

        self.materials.deinit();
        self.settings.deinit();
        self.root.deinit();
    }

    fn findSettings(self: *Scene) void {
        for (self.settings.children.items) |s| {
            if (std.mem.eql(u8, s.node_type.name, "Camera Settings")) {
                self.camera_settings = s;
                break;
            }
        }
        for (self.settings.children.items) |s| {
            if (std.mem.eql(u8, s.node_type.name, "Environment Settings")) {
                self.environment_settings = s;
                break;
            }
        }
    }

    fn recursiveSave(node: *SceneNode, writer: anytype) std.os.WriteError!void {
        const name: []const u8 = std.mem.sliceTo(&node.name, 0);

        try writer.writeIntBig(u32, @intCast(u32, name.len));
        try writer.writeAll(name);

        try writer.writeIntBig(u32, @intCast(u32, node.node_type.name.len));
        try writer.writeAll(node.node_type.name);

        try writer.writeAll(node.buffer);

        try writer.writeIntBig(u32, @intCast(u32, node.childrenCount()));
        for (node.children.items) |child|
            try recursiveSave(child, writer);
    }

    fn saveRoot(root: *SceneNode, writer: anytype) std.os.WriteError!void {
        try writer.writeIntBig(u32, @intCast(u32, root.childrenCount()));
        for (root.children.items) |child|
            try recursiveSave(child, writer);
    }

    pub fn save(self: *Scene, path: []const u8) !void {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = try cwd.createFile(path, .{ .read = true, .truncate = true });
        defer file.close();

        const writer = file.writer();

        try saveRoot(&self.root, &writer);
        try saveRoot(&self.settings, &writer);
        try saveRoot(&self.materials, &writer);
    }

    pub fn saveNyanSdf(self: *Scene, path: []const u8) !void {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = try cwd.createFile(path, .{ .read = true, .truncate = true });
        defer file.close();

        const writer = file.writer();

        try saveRoot(&self.materials, &writer);
        try saveRoot(&self.root, &writer);
    }

    fn recursiveLoad(parent: *SceneNode, reader: anytype) (std.os.ReadError || EndOfStreamError)!void {
        var node: *SceneNode = parent.add();

        const name_len: usize = try reader.readIntBig(u32);
        _ = try reader.readAll(node.name[0..name_len]);
        node.name[name_len] = 0;

        const node_type_len: usize = try reader.readIntBig(u32);
        var node_type_name: []u8 = nyan.app.allocator.alloc(u8, node_type_len) catch unreachable;
        defer nyan.app.allocator.free(node_type_name);
        _ = try reader.readAll(node_type_name);

        const node_type: *const NodeType = node_collection.node_map.get(node_type_name).?;
        node.initWithoutName(node_type, parent);

        _ = try reader.readAll(node.buffer);

        if (node_type.has_on_load)
            node_type.on_load_fn(&node.buffer);

        var children_count: usize = try reader.readIntBig(u32);
        while (children_count > 0) : (children_count -= 1)
            try recursiveLoad(node, reader);
    }

    fn loadRoot(parent: *SceneNode, reader: anytype) (std.os.ReadError || EndOfStreamError)!void {
        var root_level_nodes_count: usize = try reader.readIntBig(u32);
        while (root_level_nodes_count > 0) : (root_level_nodes_count -= 1)
            try recursiveLoad(parent, reader);
    }

    // Doesn't recompile scene shaders!!!
    pub fn load(self: *Scene, path: []const u8) !void {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = try cwd.openFile(path, .{ .read = true });
        defer file.close();

        self.materials.deinit();
        self.settings.deinit();
        self.root.deinit();

        self.createRoots();

        const reader = file.reader();

        try loadRoot(&self.root, &reader);
        try loadRoot(&self.settings, &reader);
        try loadRoot(&self.materials, &reader);

        self.findSettings();
    }

    pub fn recompile(self: *Scene) void {
        if (self.shader) |sh|
            sh.destroy();

        self.shader = scene2shader(self, &self.settings);

        nyan.global_render_graph.changeResourceBetweenFrames(&self.rg_resource, rebuildRenderGraph);
    }

    fn rebuildRenderGraph(res: *nyan.RGResource) void {
        _ = res;
        nyan.global_render_graph.needs_rebuilding = true;
    }
};
