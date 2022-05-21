const std = @import("std");
const nyan = @import("nyancore");
const nsdf = nyan.Sdf;
const nm = nyan.Math;
const vk = nyan.vk;

const Scene = @import("scene.zig").Scene;
const SceneNode = @import("scene_node.zig").SceneNode;
const NodeType = @import("../nodes/node_type.zig").NodeType;

const FileNodeData = @import("../nodes/special/file_scene_node.zig").Data;
const sbn = @import("../nodes/special/sphere_bound.zig");

const Global = @import("../global.zig");
const FileWatcher = @import("file_watcher.zig").FileWatcher;

pub fn scene2shader(scene: *Scene, settings: *SceneNode) vk.ShaderModule {
    const code: []const u8 = scene2code(scene, settings, nsdf.Templates.layout, nsdf.Templates.shader_main);
    //std.debug.print("{s}\n", .{code});

    // =c Crashes compiler in zig 0.8
    //const code_zero: [:0]const u8 = code[0..code_len :0];
    const code_zero: [:0]const u8 = nyan.app.allocator.dupeZ(u8, code) catch unreachable;
    const res: vk.ShaderModule = nyan.shader_util.loadShader(code_zero, .fragment);

    nyan.app.allocator.free(code);
    nyan.app.allocator.free(code_zero);

    return res;
}

pub fn scene2computeShader(scene: *Scene, settings: *SceneNode, custom_layout: []const u8, main_fnc: []const u8) vk.ShaderModule {
    const code: []const u8 = scene2code(scene, settings, custom_layout, main_fnc);

    const code_zero: [:0]const u8 = nyan.app.allocator.dupeZ(u8, code) catch unreachable;
    const res: vk.ShaderModule = nyan.shader_util.loadShader(code_zero, .compute);

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

    sphere_bounds: std.ArrayList(nm.sphereBound),
    bounded: std.AutoArrayHashMap(*SceneNode, *nm.sphereBound),
    sphere_bound_node: SceneNode,
    sphere_bound_index: usize,

    used_node_types: NodeTypesArray,
    node_iter: usize,
    cur_mat_offset: usize,

    node_commands: TextArray,
    shadow_node_commands: TextArray,
    node_with_mat_commands: TextArray,

    iteration_context: nsdf.IterationContext,

    pub fn create(allocator: std.mem.Allocator) Context {
        var sphere_bound_node: SceneNode = undefined;
        sphere_bound_node.initWithoutName(&sbn.SphereBoundNode, null);

        return .{
            .file_to_material_offset = FileMatOffsetMap.init(allocator),
            .used_material_types = NodeTypesArray.init(allocator),
            .used_materials = NodeArray.init(allocator),

            .sphere_bounds = std.ArrayList(nm.sphereBound).init(allocator),
            .bounded = std.AutoArrayHashMap(*SceneNode, *nm.sphereBound).init(allocator),
            .sphere_bound_node = sphere_bound_node,
            .sphere_bound_index = 0,

            .used_node_types = NodeTypesArray.init(allocator),
            .node_iter = 0,
            .cur_mat_offset = 0,

            .node_commands = TextArray.init(allocator),
            .shadow_node_commands = TextArray.init(allocator),
            .node_with_mat_commands = TextArray.init(allocator),

            .iteration_context = nsdf.IterationContext.create(allocator),
        };
    }
    pub fn destroy(self: *Context) void {
        self.iteration_context.destroy();

        self.file_to_material_offset.deinit();
        self.used_material_types.deinit();
        self.used_materials.deinit();

        self.sphere_bounds.deinit();
        self.bounded.deinit();
        self.sphere_bound_node.deinit();

        self.used_node_types.deinit();

        self.node_commands.deinit();
        self.shadow_node_commands.deinit();
        self.node_with_mat_commands.deinit();
    }
};

fn scene2code(scene: *Scene, settings: *SceneNode, layout: []const u8, main_fnc: []const u8) []const u8 {
    var context = Context.create(nyan.app.allocator);
    defer context.destroy();

    context.sphere_bounds.resize(1) catch unreachable;
    allocateSphereBounds(&context, &scene.root);
    computeSphereBounds(&context, &scene.root, &context.sphere_bounds.items[0], 0);
    if (context.bounded.count() > 0)
        context.used_node_types.append(context.sphere_bound_node.node_type) catch unreachable;

    iterateMaterials(&context, &scene.materials, "");

    iterateNode(&context, &scene.root);

    const settings_defines: []const u8 = settingsDefines(&context, settings);
    defer nyan.app.allocator.free(settings_defines);

    const function_decls: []const u8 = functionDecls(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(function_decls);

    const map_commands: []const u8 = mapCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(map_commands);

    const shadow_map_commands: []const u8 = shadowMapCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(shadow_map_commands);

    const map_return: []const u8 = std.fmt.allocPrint(nyan.app.allocator, "return d{d};\n", .{context.iteration_context.last_value_set_index}) catch unreachable;
    defer nyan.app.allocator.free(map_return);

    const shadow_map_return: []const u8 = std.fmt.allocPrint(nyan.app.allocator, "return d{d};\n", .{context.iteration_context.last_value_set_index}) catch unreachable;
    defer nyan.app.allocator.free(shadow_map_return);

    const mat_to_color_commands: []const u8 = matToColorCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(mat_to_color_commands);

    const mat_map_commands: []const u8 = matMapCommands(&context, nyan.app.allocator);
    defer nyan.app.allocator.free(mat_map_commands);

    const code_pieces = [_][]const u8{
        "#version 450\n",
        settings_defines,
        layout,
        nsdf.Templates.shader_header,
        function_decls,
        nsdf.Templates.map_header,
        map_commands,
        if (context.iteration_context.any_value_set) map_return else "return 1e10;\n",
        nsdf.Templates.map_footer,
        nsdf.Templates.shadow_map_header,
        shadow_map_commands,
        if (context.iteration_context.any_value_set) shadow_map_return else "return 1e10;\n",
        nsdf.Templates.shadow_map_footer,
        nsdf.Templates.mat_to_color_header,
        mat_to_color_commands,
        nsdf.Templates.mat_to_color_footer,
        nsdf.Templates.mat_map_header,
        mat_map_commands,
        nsdf.Templates.mat_map_footer,
        nsdf.Templates.shader_normal_and_shadows,
        main_fnc,
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

fn shadowMapCommands(ctxt: *Context, allocator: std.mem.Allocator) []const u8 {
    const res: []const u8 = std.mem.concat(allocator, u8, ctxt.shadow_node_commands.items) catch unreachable;
    for (ctxt.shadow_node_commands.items) |c|
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

fn allocateSphereBounds(ctxt: *Context, node: *SceneNode) void {
    ctxt.sphere_bounds.resize(ctxt.sphere_bounds.items.len + node.children.items.len) catch unreachable;
    for (node.children.items) |c|
        allocateSphereBounds(ctxt, c);
}

fn computeSphereBounds(ctxt: *Context, node: *SceneNode, sphere_bound: *nm.sphereBound, level: usize) void {
    const bound_each_level: usize = 2;
    const no_bound: nm.sphereBound = .{ .pos = nyan.Math.Vec3.zeros(), .r = 0.0 };

    const child_start: usize = ctxt.sphere_bound_index;
    const child_end: usize = child_start + node.children.items.len;
    ctxt.sphere_bound_index = child_end;

    for (node.children.items) |c, i| {
        if (c.node_type.external) {
            const path: []const u8 = std.mem.sliceTo(&@ptrCast(*FileNodeData, &c.buffer).file_path, 0);
            const fw: *FileWatcher = &Global.file_watcher;
            const scene: *Scene = &fw.map.get(path).?.scene;
            computeSphereBounds(ctxt, &scene.root, &ctxt.sphere_bounds.items[child_start + i], level + 1);
        } else {
            computeSphereBounds(ctxt, c, &ctxt.sphere_bounds.items[child_start + i], level + 1);
        }
    }

    if (node.children.items.len < node.node_type.min_child_count) {
        sphere_bound.* = no_bound;
        return;
    }

    node.node_type.sphere_bound_fn(&node.buffer, sphere_bound, ctxt.sphere_bounds.items[child_start..child_end]);

    if (level % bound_each_level == 0)
        ctxt.bounded.put(node, sphere_bound) catch unreachable;
}

fn enterCommand(ctxt: *Context, node: *SceneNode, comptime add_to_shadow: bool) void {
    const enter_command: []const u8 = node.node_type.enter_command_fn(
        &ctxt.iteration_context,
        ctxt.node_iter,
        ctxt.cur_mat_offset,
        &node.buffer,
    );
    ctxt.node_commands.append(enter_command) catch unreachable;
    ctxt.node_with_mat_commands.append(nyan.app.allocator.dupe(u8, enter_command) catch unreachable) catch unreachable;

    if (add_to_shadow)
        ctxt.shadow_node_commands.append(nyan.app.allocator.dupe(u8, enter_command) catch unreachable) catch unreachable;

    ctxt.node_iter += 1;
}

fn exitCommand(ctxt: *Context, node: *SceneNode) void {
    const exit_command: []const u8 = node.node_type.exit_command_fn(&ctxt.iteration_context, ctxt.node_iter, &node.buffer);
    ctxt.node_commands.append(exit_command) catch unreachable;
    ctxt.node_with_mat_commands.append(node.node_type.append_mat_check_fn(
        &ctxt.iteration_context,
        exit_command,
        &node.buffer,
        ctxt.cur_mat_offset,
        nyan.app.allocator,
    )) catch unreachable;

    ctxt.shadow_node_commands.append(nyan.app.allocator.dupe(u8, exit_command) catch unreachable) catch unreachable;

    ctxt.node_iter += 1;
}

fn iterateNode(ctxt: *Context, node: *SceneNode) void {
    var found: bool = for (ctxt.used_node_types.items) |used_type| {
        if (used_type == node.node_type)
            break true;
    } else false;

    if (!found)
        ctxt.used_node_types.append(node.node_type) catch unreachable;

    const bounded: bool = ctxt.bounded.contains(node) and ctxt.bounded.get(node).?.*.r != std.math.inf(f32);
    if (bounded) {
        const data: *sbn.Data = @ptrCast(*sbn.Data, @alignCast(@alignOf(sbn.Data), ctxt.sphere_bound_node.buffer.ptr));
        data.bound = ctxt.bounded.get(node).?.*;
        const enter_command: []const u8 = nsdf.SphereBoundNode.shadowEnterCommand(
            &ctxt.iteration_context,
            ctxt.node_iter,
            ctxt.cur_mat_offset,
            &ctxt.sphere_bound_node.buffer,
        );
        ctxt.shadow_node_commands.append(enter_command) catch unreachable;
        enterCommand(ctxt, &ctxt.sphere_bound_node, false);
    }

    enterCommand(ctxt, node, true);

    for (node.children.items) |ch| {
        if (ch.node_type.external) {
            iterateExternNode(ctxt, ch);
        } else {
            iterateNode(ctxt, ch);
        }
    }

    exitCommand(ctxt, node);

    if (bounded) {
        const data: *sbn.Data = @ptrCast(*sbn.Data, @alignCast(@alignOf(sbn.Data), ctxt.sphere_bound_node.buffer.ptr));
        data.bound = ctxt.bounded.get(node).?.*;
        exitCommand(ctxt, &ctxt.sphere_bound_node);
    }
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
