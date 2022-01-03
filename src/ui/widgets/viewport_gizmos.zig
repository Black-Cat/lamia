const nyan = @import("nyancore");
const nc = nyan.c;
const nm = nyan.Math;
const std = @import("std");
const Allocator = std.mem.Allocator;
const Camera = @import("../../scene/camera.zig").Camera;
const CameraData = @import("../../nodes/scene_settings/camera_settings.zig").Data;
const SceneNode = @import("../../scene/scene_node.zig").SceneNode;
const Global = @import("../../global.zig");
const UI = @import("../ui.zig");

pub const SizeGizmo = struct {
    const DirectionType = enum { static, cross };
    const OffsetType = enum { direction, position };

    size: *f32,

    dir: nm.vec3,
    direction_type: DirectionType,
    dir_points: [2]*nm.vec3,

    offset_dist: ?*f32,
    offset_type: OffsetType,
    offset_dir: nm.vec3,
    offset_pos: ?*nm.vec3,
};

pub const TranslationGizmo = struct {
    pos: *nm.vec3,
};

pub const RotationGizmo = struct {
    dir: *nm.vec3,

    offset_dist: *f32,
    offset_dir: nm.vec3,
};

pub const GizmoStorage = struct {
    size_gizmos: std.ArrayList(SizeGizmo),
    translation_gizmos: std.ArrayList(TranslationGizmo),
    rotation_gizmos: std.ArrayList(RotationGizmo),

    scene_node: ?*SceneNode,
    points_to_transform: std.ArrayList(nm.vec4),

    pub fn init(self: *GizmoStorage, allocator: Allocator) void {
        self.size_gizmos = std.ArrayList(SizeGizmo).init(allocator);
        self.translation_gizmos = std.ArrayList(TranslationGizmo).init(allocator);
        self.rotation_gizmos = std.ArrayList(RotationGizmo).init(allocator);

        self.scene_node = null;
        self.points_to_transform = std.ArrayList(nm.vec4).init(allocator);
    }

    pub fn deinit(self: *GizmoStorage) void {
        self.size_gizmos.deinit();
        self.translation_gizmos.deinit();
        self.rotation_gizmos.deinit();
        self.points_to_transform.deinit();
    }

    pub fn clear(self: *GizmoStorage) void {
        self.size_gizmos.clearRetainingCapacity();
        self.translation_gizmos.clearRetainingCapacity();
        self.rotation_gizmos.clearRetainingCapacity();
        self.points_to_transform.clearRetainingCapacity();
    }

    pub fn fillFromNode(self: *GizmoStorage, node: ?*SceneNode) void {
        self.clear();
        self.scene_node = node;

        if (self.scene_node == null)
            return;

        self.scene_node.?.node_type.appendGizmosFn(&self.scene_node.?.buffer, self);
        self.points_to_transform.resize(3 * self.size_gizmos.items.len + 4 * self.translation_gizmos.items.len) catch unreachable;
    }
};

pub const InteractionInfo = struct {
    draw_list: *nc.ImDrawList = undefined,

    camera: *Camera = undefined,
    viewport: nm.vec4 = undefined,

    center: nm.vec2 = undefined,
    original_point: nm.vec2 = undefined,
    center3: nm.vec3 = undefined,
    original_point3: nm.vec3 = undefined,
    direction: nm.vec3 = undefined,

    view_mat: nm.mat4x4 = undefined,
    persp_mat: nm.mat4x4 = undefined,

    original_value: f32 = undefined,
    original_value3: nm.vec3 = undefined,

    value: *f32 = undefined,
    value3: *nm.vec3 = undefined,

    interactFn: ?fn (interaction_info: *InteractionInfo) void = null,
};

fn transformPoints(gizmos: *GizmoStorage, camera: *Camera, interaction_info: *InteractionInfo) void {
    // Copy current point positions
    var points_count: usize = 0;
    for (gizmos.size_gizmos.items) |*sg| {
        const center_index: usize = points_count;

        gizmos.points_to_transform.items[center_index] = .{ 0.0, 0.0, 0.0, 1.0 };

        if (sg.offset_type == .direction and sg.offset_dist != null) {
            gizmos.points_to_transform.items[center_index] = nm.Vec4.fromVec3(sg.offset_dir * @splat(3, sg.offset_dist.?.*), 0.0);
        } else if (sg.offset_type == .position and sg.offset_pos != null) {
            gizmos.points_to_transform.items[center_index] = nm.Vec4.fromVec3(sg.offset_pos.?.*, 0.0);
        }
        points_count += 1;

        if (sg.direction_type == .cross) {
            const dir_vec: nm.vec3 = sg.dir_points[1].* - sg.dir_points[0].*;
            var temp: nm.vec3 = .{ 0.0, 0.0, 1.0 };
            if (dir_vec[0] == temp[0] and dir_vec[1] == temp[1])
                temp[0] = 1.0;
            sg.dir = nm.Vec3.normalize(nm.Vec3.cross(dir_vec, temp));
        }

        const point_offset: nm.vec3 = sg.dir * @splat(3, sg.size.*);

        gizmos.points_to_transform.items[points_count] = gizmos.points_to_transform.items[center_index] + nm.Vec4.fromVec3(point_offset, 0.0);
        gizmos.points_to_transform.items[points_count][3] = 1.0;
        points_count += 1;
        gizmos.points_to_transform.items[points_count] = gizmos.points_to_transform.items[center_index] - nm.Vec4.fromVec3(point_offset, 0.0);
        gizmos.points_to_transform.items[points_count][3] = 1.0;
        points_count += 1;
    }

    for (gizmos.translation_gizmos.items) |tg| {
        const center_index: usize = points_count;
        gizmos.points_to_transform.items[center_index] = nm.Vec4.fromVec3(tg.pos.*, 1.0);
        points_count += 1;

        var d: usize = 0;
        while (d < 3) : (d += 1) {
            var dir: nm.vec4 = .{ 0.0, 0.0, 0.0, 0.0 };
            dir[d] = 1.0;
            gizmos.points_to_transform.items[points_count] = gizmos.points_to_transform.items[center_index] + dir;
            gizmos.points_to_transform.items[points_count][3] = 1.0;
            points_count += 1;
        }
    }

    // Apply node transformations
    var cur_node: *SceneNode = gizmos.scene_node.?;
    while (cur_node.parent != null) {
        cur_node.node_type.modifyGizmoPointsFn(&cur_node.buffer, gizmos.points_to_transform.items);
        cur_node = cur_node.parent.?;
    }

    // Transform to screen coordinates
    interaction_info.view_mat = nm.Mat4x4.lookAt(camera.position, camera.target, camera.up);

    const camera_settings: *CameraData = @ptrCast(*CameraData, @alignCast(@alignOf(*CameraData), Global.main_scene.camera_settings.buffer.ptr));
    const aspect: f32 = interaction_info.viewport[2] / interaction_info.viewport[3];
    var fov_y: f32 = camera_settings.fov;
    if (interaction_info.viewport[3] > interaction_info.viewport[2])
        fov_y /= aspect;
    interaction_info.persp_mat = nm.Mat4x4.perspective(nm.rad(fov_y), aspect, camera_settings.near, camera_settings.far);

    const view_proj: nm.mat4x4 = nm.Mat4x4.mul(interaction_info.persp_mat, interaction_info.view_mat);

    for (gizmos.points_to_transform.items) |*p| {
        p.* = nm.Mat4x4.mulv(view_proj, p.*);
        if (p.*[3] != 0.0)
            p.* *= nm.vec4{ 1.0 / p.*[3], 1.0 / p.*[3], 1.0 / p.*[3], 1.0 };
        p.*[1] *= -1.0;
        p.* += nm.vec4{ 1.0, 1.0, 1.0, 0.0 };
        p.* /= nm.vec4{ 2.0, 2.0, 2.0, 1.0 };
    }
}

// Based on http://paulbourke.net/geometry/pointlineplane/calclineline.cs
fn solveLineLineIntersection(a: nm.vec3, ad: nm.vec3, b: nm.vec3, bd: nm.vec3) f32 {
    const ab: nm.vec3 = a - b;

    const dabbd: f32 = nm.Vec3.dot(ab, bd);
    const dbdad: f32 = nm.Vec3.dot(bd, ad);
    const dabad: f32 = nm.Vec3.dot(ab, ad);
    const dbdbd: f32 = nm.Vec3.dot(bd, bd);
    const dadad: f32 = nm.Vec3.dot(ad, ad);

    const denom: f32 = dadad * dbdbd - dbdad * dbdad;
    const numer: f32 = dabbd * dbdad - dabad * dbdbd;

    const mua: f32 = numer / denom;
    return mua;
}

fn interactChangeSize(interaction_info: *InteractionInfo) void {
    const io: *nc.ImGuiIO = nc.igGetIO();
    const mouse_pos: nm.vec3 = .{ io.MousePos.x, io.MousePos.y, 0.0 };

    var orig_vector: nm.vec3 = interaction_info.original_point3 - interaction_info.center3;
    const orig_vector_norm: f32 = nm.Vec3.norm(orig_vector);
    orig_vector = nm.Vec3.normalize(orig_vector);

    const view_proj: nm.mat4x4 = nm.Mat4x4.mul(interaction_info.persp_mat, interaction_info.view_mat);

    const mouse_pos_world: nm.vec3 = nm.Mat4x4.unproject(mouse_pos, view_proj, interaction_info.viewport);

    const camera_dir: nm.vec3 = nm.Vec3.normalize(mouse_pos_world - interaction_info.camera.position);

    const intersection: f32 = solveLineLineIntersection(interaction_info.center3, orig_vector, interaction_info.camera.position, camera_dir);
    interaction_info.value.* = interaction_info.original_value * (@fabs(intersection) / orig_vector_norm);
}

fn drawHandlePair(p: [*]nm.vec4, gizmo: *SizeGizmo, interaction_info: *InteractionInfo) void {
    const handle_hover_radius: f32 = 8.0;

    const centers: [3]nc.ImVec2 = .{
        .{
            .x = interaction_info.viewport[0] + interaction_info.viewport[2] * p[1][0],
            .y = interaction_info.viewport[1] + interaction_info.viewport[3] * p[1][1],
        },
        .{
            .x = interaction_info.viewport[0] + interaction_info.viewport[2] * p[2][0],
            .y = interaction_info.viewport[1] + interaction_info.viewport[3] * p[2][1],
        },
        .{
            .x = interaction_info.viewport[0] + interaction_info.viewport[2] * p[0][0],
            .y = interaction_info.viewport[1] + interaction_info.viewport[3] * p[0][1],
        },
    };

    const io: *nc.ImGuiIO = nc.igGetIO();
    const mouse_pos: nc.ImVec2 = io.MousePos;

    const dist_sqr: [2]f32 = .{
        (centers[0].x - mouse_pos.x) * (centers[0].x - mouse_pos.x) + (centers[0].y - mouse_pos.y) * (centers[0].y - mouse_pos.y),
        (centers[1].x - mouse_pos.x) * (centers[1].x - mouse_pos.x) + (centers[1].y - mouse_pos.y) * (centers[1].y - mouse_pos.y),
    };

    const hovered: [2]bool = .{
        dist_sqr[0] <= handle_hover_radius * handle_hover_radius,
        dist_sqr[1] <= handle_hover_radius * handle_hover_radius,
    };

    var hovered_ind: usize = undefined;
    const is_hovered: bool = for (hovered) |h, ind| {
        if (h) {
            hovered_ind = ind;
            break true;
        }
    } else false;

    var col: nc.ImVec4 = undefined;
    var drawn_radius: f32 = undefined;
    if (is_hovered) {
        col = UI.mainColors[1];
        drawn_radius = 8.0;
    } else {
        col = UI.mainColors[4];
        drawn_radius = 5.0;
    }

    const col32: nc.ImU32 = nc.igColorConvertFloat4ToU32(col);
    nc.ImDrawList_AddCircleFilled(interaction_info.draw_list, centers[0], drawn_radius, col32, 6);
    nc.ImDrawList_AddCircleFilled(interaction_info.draw_list, centers[1], drawn_radius, col32, 6);

    if (io.MouseDown[0] and interaction_info.interactFn == null and is_hovered) {
        interaction_info.center[0] = centers[2].x;
        interaction_info.center[1] = centers[2].y;
        interaction_info.original_point[0] = centers[hovered_ind].x;
        interaction_info.original_point[1] = centers[hovered_ind].y;
        if (gizmo.offset_type == .direction and gizmo.offset_dist != null) {
            interaction_info.center3 = gizmo.offset_dir * @splat(3, gizmo.offset_dist.?.*);
        } else if (gizmo.offset_type == .position and gizmo.offset_pos != null) {
            interaction_info.center3 = gizmo.offset_pos.?.*;
        } else {
            interaction_info.center3 = nm.vec3{ 0.0, 0.0, 0.0 };
        }
        interaction_info.original_point3 = interaction_info.center3 + gizmo.dir * @splat(3, gizmo.size.*);
        interaction_info.original_value = gizmo.size.*;
        interaction_info.value = gizmo.size;
        interaction_info.interactFn = interactChangeSize;
        interaction_info.direction = gizmo.dir;
    }
}

fn drawSizeGizmos(point_offset: *usize, gizmos: *GizmoStorage, interaction_info: *InteractionInfo) void {
    for (gizmos.size_gizmos.items) |*sg, ind| {
        const i: usize = point_offset.* + 3 * ind;
        drawHandlePair(@ptrCast([*]nm.vec4, &gizmos.points_to_transform.items[i]), sg, interaction_info);
    }
    point_offset.* += gizmos.size_gizmos.items.len * 3;
}

fn interactChangePos(interaction_info: *InteractionInfo) void {
    const io: *nc.ImGuiIO = nc.igGetIO();
    const mouse_pos: nm.vec3 = .{ io.MousePos.x, io.MousePos.y, 0.0 };

    const view_proj: nm.mat4x4 = nm.Mat4x4.mul(interaction_info.persp_mat, interaction_info.view_mat);

    const mouse_pos_world: nm.vec3 = nm.Mat4x4.unproject(mouse_pos, view_proj, interaction_info.viewport);

    const camera_dir: nm.vec3 = nm.Vec3.normalize(mouse_pos_world - interaction_info.camera.position);

    const intersection: f32 = solveLineLineIntersection(interaction_info.value3.*, interaction_info.direction, interaction_info.camera.position, camera_dir);

    const offset: nm.vec3 = interaction_info.direction * @splat(3, intersection - interaction_info.original_value);
    interaction_info.value3.* += offset;
}

fn drawTranslationAxis(p: [*]nm.vec4, gizmo: *TranslationGizmo, interaction_info: *InteractionInfo) void {
    const centers: [4]nm.vec2 = .{
        .{
            interaction_info.viewport[0] + interaction_info.viewport[2] * p[1][0],
            interaction_info.viewport[1] + interaction_info.viewport[3] * p[1][1],
        },
        .{
            interaction_info.viewport[0] + interaction_info.viewport[2] * p[2][0],
            interaction_info.viewport[1] + interaction_info.viewport[3] * p[2][1],
        },
        .{
            interaction_info.viewport[0] + interaction_info.viewport[2] * p[3][0],
            interaction_info.viewport[1] + interaction_info.viewport[3] * p[3][1],
        },
        .{
            interaction_info.viewport[0] + interaction_info.viewport[2] * p[0][0],
            interaction_info.viewport[1] + interaction_info.viewport[3] * p[0][1],
        },
    };

    const io: *nc.ImGuiIO = nc.igGetIO();
    const mouse_pos: nm.vec2 = .{ io.MousePos.x, io.MousePos.y };

    const mouse_dir: nm.vec2 = mouse_pos - centers[3];

    var dist: nm.vec3 = undefined;
    var dist_proj: nm.vec3 = undefined;
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        var axis_dir: nm.vec2 = centers[i] - centers[3];

        const t: f32 = nm.clamp_zo(nm.Vec2.dot(mouse_dir, axis_dir) / nm.Vec2.dot(axis_dir, axis_dir));

        axis_dir *= @splat(2, t);
        axis_dir = mouse_dir - axis_dir;

        dist[i] = nm.Vec2.norm2(axis_dir);
        dist_proj[i] = t;
    }

    var hovered_ind: usize = 0;
    i = 1;
    while (i < 3) : (i += 1) {
        if (dist[i] < dist[hovered_ind])
            hovered_ind = i;
    }

    const hovered: bool = dist[hovered_ind] <= 8.0 * 8.0;

    i = 0;
    while (i < 3) : (i += 1) {
        const col: nc.ImVec4 = .{
            .x = @intToFloat(f32, @boolToInt(i == 0)),
            .y = @intToFloat(f32, @boolToInt(i == 1)),
            .z = @intToFloat(f32, @boolToInt(i == 2)),
            .w = 1.0,
        };
        const col32 = nc.igColorConvertFloat4ToU32(col);

        nc.ImDrawList_AddLine(
            interaction_info.draw_list,
            .{ .x = centers[3][0], .y = centers[3][1] },
            .{ .x = centers[i][0], .y = centers[i][1] },
            col32,
            if (hovered and hovered_ind == i) 3.0 else 1.0,
        );
    }

    if (io.MouseDown[0] and interaction_info.interactFn == null and hovered) {
        interaction_info.center = centers[3];
        interaction_info.original_point = centers[hovered_ind];

        interaction_info.center3 = gizmo.pos.*;
        interaction_info.direction[0] = @intToFloat(f32, @boolToInt(hovered_ind == 0));
        interaction_info.direction[1] = @intToFloat(f32, @boolToInt(hovered_ind == 1));
        interaction_info.direction[2] = @intToFloat(f32, @boolToInt(hovered_ind == 2));
        interaction_info.original_point3 = interaction_info.center3 + interaction_info.direction;

        interaction_info.original_value3 = interaction_info.center3;
        interaction_info.value3 = gizmo.pos;
        interaction_info.original_value = dist_proj[hovered_ind];
        interaction_info.interactFn = interactChangePos;
    }
}

fn drawTranslationGizmos(point_offset: *usize, gizmos: *GizmoStorage, interaction_info: *InteractionInfo) void {
    for (gizmos.translation_gizmos.items) |*tg, ind| {
        const i: usize = point_offset.* + 4 * ind;
        drawTranslationAxis(@ptrCast([*]nm.vec4, &gizmos.points_to_transform.items[i]), tg, interaction_info);
    }
    point_offset.* += gizmos.translation_gizmos.items.len * 4;
}

pub fn drawGizmos(gizmos: *GizmoStorage, interaction_info: *InteractionInfo, camera: *Camera, min_pos: nc.ImVec2, max_pos: nc.ImVec2, window_pos: nc.ImVec2) void {
    if (gizmos.points_to_transform.items.len == 0)
        return;

    interaction_info.camera = camera;

    interaction_info.draw_list = nc.igGetWindowDrawList();
    interaction_info.viewport[0] = window_pos.x + min_pos.x;
    interaction_info.viewport[1] = window_pos.y + min_pos.y;
    interaction_info.viewport[2] = max_pos.x - min_pos.x;
    interaction_info.viewport[3] = max_pos.y - min_pos.y;

    transformPoints(gizmos, camera, interaction_info);

    var point_offset: usize = 0;
    drawSizeGizmos(&point_offset, gizmos, interaction_info);
    drawTranslationGizmos(&point_offset, gizmos, interaction_info);

    const io: *nc.ImGuiIO = nc.igGetIO();
    if (!io.MouseDown[0])
        interaction_info.interactFn = null;

    if (interaction_info.interactFn) |interactFn| {
        interactFn(interaction_info);
        Global.main_scene.recompile();
    }
}
