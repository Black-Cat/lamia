const std = @import("std");
const nyan = @import("nyancore");
const nsdf = nyan.Sdf;
const vk = nyan.vk;

const Scene = @import("scene.zig").Scene;
const SceneNode = @import("scene_node.zig").SceneNode;
const NodeType = @import("../nodes/node_type.zig").NodeType;
const FileNodeData = @import("../nodes/special/file_scene_node.zig").Data;

const Global = @import("../global.zig");
const FileWatcher = @import("file_watcher.zig").FileWatcher;

pub fn scene2shader(scene: *Scene, settings: *SceneNode) vk.ShaderModule {
    const code: []const u8 = scene2code(scene, settings);
    //std.debug.print("{s}\n", .{code});

    // =c Crashes compiler in zig 0.8
    //const code_zero: [:0]const u8 = code[0..code_len :0];
    const code_zero: [:0]const u8 = nyan.app.allocator.dupeZ(u8, code) catch unreachable;
    const res: vk.ShaderModule = nyan.shader_util.loadShader(code_zero, .fragment);

    nyan.app.allocator.free(code);
    nyan.app.allocator.free(code_zero);

    return res;
}

const FileMatOffsetMap = std.StringHashMap(usize);
const NodeTypesArray = std.ArrayList(*const NodeType);
const NodeArray = std.ArrayList(*SceneNode);
const TextArray = std.ArrayList([]const u8);

const Context = struct {
    file_to_material_offset: FileMatOffsetMap,
    used_material_types: NodeTypesArray,
    used_materials: NodeArray,

    used_node_types: NodeTypesArray,
    node_iter: usize,
    cur_mat_offset: usize,

    node_commands: TextArray,
    node_with_mat_commands: TextArray,

    iteration_context: nsdf.IterationContext,

    pub fn create(allocator: std.mem.Allocator) Context {
        return .{
            .file_to_material_offset = FileMatOffsetMap.init(allocator),
            .used_material_types = NodeTypesArray.init(allocator),
            .used_materials = NodeArray.init(allocator),

            .used_node_types = NodeTypesArray.init(allocator),
            .node_iter = 0,
            .cur_mat_offset = 0,

            .node_commands = TextArray.init(allocator),
            .node_with_mat_commands = TextArray.init(allocator),

            .iteration_context = nsdf.IterationContext.create(allocator),
        };
    }
    pub fn destroy(self: *Context) void {
        self.iteration_context.destroy();

        self.file_to_material_offset.deinit();
        self.used_material_types.deinit();
        self.used_materials.deinit();

        self.used_node_types.deinit();

        self.node_commands.deinit();
        self.node_with_mat_commands.deinit();
    }
};

fn scene2code(scene: *Scene, settings: *SceneNode) []const u8 {
    var context = Context.create(nyan.app.allocator);
    defer context.destroy();

    iterateMaterials(&context, &scene.materials, "");

    for (scene.root.children.items) |ch| {
        if (ch.node_type.external) {
            iterateExternNode(&context, ch);
        } else {
            iterateNode(&context, ch);
        }
    }

    const settings_defines: []const u8 = settingsDefines(&context, settings);
    defer nyan.app.allocator.free(settings_defines);

    const function_decls: []const u8 = functionDecls(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(function_decls);

    const map_commands: []const u8 = mapCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(map_commands);

    const map_return: []const u8 = std.fmt.allocPrint(nyan.app.allocator, "return d{d};\n", .{context.iteration_context.last_value_set_index}) catch unreachable;
    defer nyan.app.allocator.free(map_return);

    const mat_to_color_commands: []const u8 = matToColorCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(mat_to_color_commands);

    const mat_map_commands: []const u8 = matMapCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(mat_map_commands);

    const code_pieces = [_][]const u8{
        "#version 450\n",
        settings_defines,
        nsdf.Templates.layout,
        nsdf.Templates.shader_header,
        function_decls,
        nsdf.Templates.map_header,
        map_commands,
        if (context.iteration_context.any_value_set) map_return else "return 1e10;\n",
        nsdf.Templates.map_footer,
        nsdf.Templates.mat_to_color_header,
        mat_to_color_commands,
        nsdf.Templates.mat_to_color_footer,
        nsdf.Templates.mat_map_header,
        mat_map_commands,
        nsdf.Templates.mat_map_footer,
        nsdf.Templates.shader_normal_and_shadows,
        nsdf.Templates.shader_main,
    };

    return std.mem.concat(nyan.app.allocator, u8, code_pieces[0..]) catch unreachable;
}

fn settingsDefines(ctxt: *Context, settings: *SceneNode) []const u8 {
    var defines: [][]const u8 = nyan.app.allocator.alloc([]const u8, settings.children.items.len) catch unreachable;

    for (settings.children.items) |s, ind|
        defines[ind] = s.node_type.enter_command_fn(&ctxt.iteration_context, 0, 0, &s.buffer);

    const res: []const u8 = std.mem.concat(nyan.app.allocator, u8, defines) catch unreachable;

    for (defines) |d|
        nyan.app.allocator.free(d);

    nyan.app.allocator.free(defines);

    return res;
}

fn functionDecls(ctxt: *Context, allocator: std.mem.Allocator) []const u8 {
    var decls: [][]const u8 = allocator.alloc([]const u8, ctxt.used_node_types.items.len + ctxt.used_material_types.items.len) catch unreachable;

    for (ctxt.used_node_types.items) |t, ind|
        decls[ind] = t.function_definition;

    for (ctxt.used_material_types.items) |t, ind|
        decls[ctxt.used_node_types.items.len + ind] = t.function_definition;

    const res: []const u8 = std.mem.concat(allocator, u8, decls) catch unreachable;

    allocator.free(decls);

    return res;
}

fn mapCommands(ctxt: *Context, allocator: std.mem.Allocator) []const u8 {
    const res: []const u8 = std.mem.concat(allocator, u8, ctxt.node_commands.items) catch unreachable;
    for (ctxt.node_commands.items) |c|
        allocator.free(c);
    return res;
}

fn matMapCommands(ctxt: *Context, allocator: std.mem.Allocator) []const u8 {
    const res: []const u8 = std.mem.concat(allocator, u8, ctxt.node_with_mat_commands.items) catch unreachable;
    for (ctxt.node_with_mat_commands.items) |c|
        allocator.free(c);
    return res;
}

fn matToColorCommands(ctxt: *Context, allocator: std.mem.Allocator) []const u8 {
    var decls: [][]const u8 = allocator.alloc([]const u8, ctxt.used_materials.items.len) catch unreachable;

    for (ctxt.used_materials.items) |mat, ind| {
        const command: []const u8 = mat.node_type.enter_command_fn(&ctxt.iteration_context, 0, 0, &mat.buffer);
        decls[ind] = std.fmt.allocPrint(allocator, "if (m < {d}.5) {{ {s} }} else ", .{ ind, command }) catch unreachable;
        allocator.free(command);
    }

    const res: []const u8 = std.mem.concat(allocator, u8, decls) catch unreachable;

    for (decls) |d|
        allocator.free(d);
    allocator.free(decls);

    return res;
}

fn iterateMaterials(ctxt: *Context, materials: *SceneNode, file: []const u8) void {
    if (ctxt.file_to_material_offset.contains(file))
        return; // Already iterated file

    ctxt.file_to_material_offset.put(file, ctxt.used_materials.items.len) catch unreachable;

    for (materials.children.items) |mat| {
        ctxt.used_materials.append(mat) catch unreachable;

        var found: bool = for (ctxt.used_material_types.items) |used_type| {
            if (used_type == mat.node_type)
                break true;
        } else false;

        if (!found)
            ctxt.used_material_types.append(mat.node_type) catch unreachable;
    }
}

fn iterateNode(ctxt: *Context, node: *SceneNode) void {
    var found: bool = for (ctxt.used_node_types.items) |used_type| {
        if (used_type == node.node_type)
            break true;
    } else false;

    if (!found)
        ctxt.used_node_types.append(node.node_type) catch unreachable;

    const enter_command: []const u8 = node.node_type.enter_command_fn(&ctxt.iteration_context, ctxt.node_iter, ctxt.cur_mat_offset, &node.buffer);
    ctxt.node_iter += 1;

    ctxt.node_commands.append(enter_command) catch unreachable;
    ctxt.node_with_mat_commands.append(nyan.app.allocator.dupe(u8, enter_command) catch unreachable) catch unreachable;

    for (node.children.items) |ch| {
        if (ch.node_type.external) {
            iterateExternNode(ctxt, ch);
        } else {
            iterateNode(ctxt, ch);
        }
    }

    const exit_command: []const u8 = node.node_type.exit_command_fn(&ctxt.iteration_context, ctxt.node_iter, &node.buffer);
    ctxt.node_commands.append(exit_command) catch unreachable;
    ctxt.node_with_mat_commands.append(node.node_type.append_mat_check_fn(exit_command, &node.buffer, ctxt.cur_mat_offset, nyan.app.allocator)) catch unreachable;

    ctxt.node_iter += 1;
}

fn iterateExternNode(ctxt: *Context, node: *SceneNode) void {
    const path: []const u8 = std.mem.sliceTo(&@ptrCast(*FileNodeData, &node.buffer).file_path, 0);

    const fw: *FileWatcher = &Global.file_watcher;

    const scene: *Scene = &fw.map.get(path).?.scene;
    iterateMaterials(ctxt, &scene.materials, path);

    const old_offset: usize = ctxt.cur_mat_offset;
    ctxt.cur_mat_offset = ctxt.file_to_material_offset.get(path).?;

    for (scene.root.children.items) |ch| {
        if (ch.node_type.external) {
            iterateExternNode(ctxt, ch);
        } else {
            iterateNode(ctxt, ch);
        }
    }

    ctxt.cur_mat_offset = old_offset;
}
