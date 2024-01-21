const nyan = @import("nyancore");
const nc = nyan.c;
const nm = nyan.Math;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;
const Global = @import("../../global.zig");

const Camera = @import("../../scene/camera.zig").Camera;
const CameraController = @import("../arcball_camera_controller.zig").ArcballCameraController;

const Export2dPopup = @import("viewport_export2d_popup.zig").Export2dPopup;

const gizmo = @import("viewport_gizmos.zig");
const drawGizmos = gizmo.drawGizmos;
const GizmoInteractionInfo = gizmo.InteractionInfo;
const GizmoStorage = gizmo.GizmoStorage;

pub const FragPushConstBlock = struct {
    eye: [4]f32,
    up: [4]f32,
    forward: [4]f32,
};

pub const Viewport = struct {
    const starting_camera_dist: f32 = 6.0;

    window: nyan.Widgets.Window,
    visible: bool,
    window_class: *nc.ImGuiWindowClass,

    camera: Camera,
    camera_controller: CameraController,

    nyanui: *nyan.UI,

    viewport_texture: nyan.ViewportTexture,
    render_pass: nyan.ScreenRenderPass(nyan.ViewportTexture),

    descriptor_pool: nyan.DescriptorPool,
    descriptor_sets: []nyan.DescriptorSets,

    frag_push_const_block: FragPushConstBlock,

    gizmo_storage: *GizmoStorage,
    gizmo_interaction: GizmoInteractionInfo,

    export2dPopup: Export2dPopup,

    pub fn init(self: *Viewport, comptime name: [:0]const u8, window_class: *nc.ImGuiWindowClass, nyanui: *nyan.UI, gizmos: *GizmoStorage) void {
        self.window = .{
            .widget = .{
                .init = windowInit,
                .deinit = windowDeinit,
                .draw = windowDraw,
            },
            .open = true,
            .strId = name,
        };

        self.visible = false;
        self.window_class = window_class;
        self.nyanui = nyanui;
        self.camera = .{
            .position = .{ 0.0, 0.0, -starting_camera_dist },
            .target = .{ 0.0, 0.0, 0.0 },
            .up = .{ 0.0, 1.0, 0.0 },
        };
        Global.cameras.append(&self.camera) catch unreachable;
        self.camera_controller = .{ .camera = &self.camera };
        self.gizmo_storage = gizmos;
        self.gizmo_interaction = .{};
        self.export2dPopup = undefined;
    }

    pub fn deinit(self: *Viewport) void {
        for (Global.cameras.items, 0..) |c, i| {
            if (c == *self.camera) {
                _ = Global.cameras.swapRemove(i);
                break;
            }
        }
    }

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        const image_format: nyan.vk.Format = nyan.global_render_graph.final_swapchain.image_format;
        self.viewport_texture.init("Viewport Texture", nyan.global_render_graph.in_flight, 128, 128, image_format, nyan.app.allocator);
        self.viewport_texture.alloc();

        nyan.global_render_graph.addResource(&self.viewport_texture, "Viewport Texture");

        self.createDescriptorPool();
        self.descriptor_sets = nyan.app.allocator.alloc(nyan.DescriptorSets, nyan.global_render_graph.in_flight) catch unreachable;
        self.allocateDescriptorSets();
        createDescriptors(&self.viewport_texture.rg_resource);

        self.render_pass.init(
            "Viewport Render Pass",
            &self.viewport_texture,
            &Global.main_scene.shader.?,
            @sizeOf(FragPushConstBlock),
            &self.frag_push_const_block,
        );

        self.render_pass.rg_pass.final_layout = .shader_read_only_optimal;

        self.render_pass.rg_pass.appendReadResource(&Global.main_scene.rg_resource);
        self.render_pass.rg_pass.appendWriteResource(&self.viewport_texture.rg_resource);
        self.render_pass.rg_pass.initFn(&self.render_pass.rg_pass);
        nyan.global_render_graph.passes.append(&self.render_pass.rg_pass) catch unreachable;
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        self.render_pass.deinit();

        self.descriptor_pool.deinit();
        self.viewport_texture.deinit();

        for (self.descriptor_sets) |*ds|
            ds.deinit();

        nyan.app.allocator.free(self.descriptor_sets);
    }

    fn windowDraw(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        nc.igSetNextWindowClass(self.window_class);
        const wasVisible = self.visible;
        self.visible = nc.igBegin(self.window.strId.ptr, &window.open, nc.ImGuiWindowFlags_None);

        if (wasVisible != self.visible) {
            if (self.visible) {
                self.nyanui.rg_pass.appendReadResource(&self.viewport_texture.rg_resource);
            } else {
                self.nyanui.rg_pass.removeReadResource(&self.viewport_texture.rg_resource);
            }
            nyan.global_render_graph.needs_rebuilding = true;
        }

        var min_pos: nc.ImVec2 = undefined;
        var max_pos: nc.ImVec2 = undefined;
        nc.igGetWindowContentRegionMin(&min_pos);
        nc.igGetWindowContentRegionMax(&max_pos);

        var window_pos: nc.ImVec2 = undefined;
        nc.igGetWindowPos(&window_pos);

        const cur_width: u32 = @intFromFloat(@round(max_pos.x - min_pos.x));
        var cur_height: u32 = @intFromFloat(@round(max_pos.y - min_pos.y));

        if (nc.igButton(Export2dPopup.name, .{ .x = 0, .y = 0 }))
            self.export2dPopup.init(&self.camera, self.viewport_texture.extent.width, self.viewport_texture.extent.height, &self.frag_push_const_block);

        var toolbar_min: nc.ImVec2 = undefined;
        var toolbar_max: nc.ImVec2 = undefined;
        nc.igGetItemRectMin(&toolbar_min);
        nc.igGetItemRectMax(&toolbar_max);

        const toolbar_height: u32 = @as(u32, @intFromFloat(toolbar_max.y)) - @as(u32, @intFromFloat(toolbar_min.y)) + @as(u32, @intFromFloat(nc.igGetStyle().*.ItemSpacing.y));
        cur_height -= toolbar_height;

        nc.igSameLine(0.0, -1.0);
        nc.igText("Camera:");
        nc.igSameLine(0.0, -1.0);
        if (nc.igButton("Top", .{ .x = 0, .y = 0 }))
            self.camera.viewAlong(.{ 0.0, -1.0, 0.0 }, .{ 0.0, 0.0, 1.0 });
        nc.igSameLine(0.0, -1.0);
        if (nc.igButton("Side", .{ .x = 0, .y = 0 }))
            self.camera.viewAlong(.{ -1.0, 0.0, 0.0 }, .{ 0.0, 1.0, 0.0 });
        nc.igSameLine(0.0, -1.0);
        if (nc.igButton("Front", .{ .x = 0, .y = 0 }))
            self.camera.viewAlong(.{ 0.0, 0.0, 1.0 }, .{ 0.0, 1.0, 0.0 });
        nc.igSameLine(0.0, -1.0);
        if (nc.igButton("Reset", .{ .x = 0, .y = 0 })) {
            self.camera.moveTargetTo(.{ 0.0, 0.0, 0.0 });
            self.camera.setDist(starting_camera_dist);
            self.camera.viewAlong(.{ 0.0, 0.0, 1.0 }, .{ 0.0, 1.0, 0.0 });
        }

        if (self.visible and (cur_width != self.viewport_texture.extent.width or cur_height != self.viewport_texture.extent.height)) {
            self.viewport_texture.resize(&nyan.global_render_graph, cur_width, cur_height);
            nyan.global_render_graph.changeResourceBetweenFrames(&self.viewport_texture.rg_resource, createDescriptors);
        }

        const size: nc.ImVec2 = .{ .x = max_pos.x - min_pos.x, .y = @floatFromInt(cur_height) };
        nc.igImage(
            @ptrCast(&self.descriptor_sets[nyan.global_render_graph.frame_index]),
            size,
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 1 },
            .{ .x = 1, .y = 1, .z = 1, .w = 1 },
            .{ .x = 0, .y = 0, .z = 0, .w = 0 },
        );

        if (self.visible) {
            self.camera_controller.handleInput();
            drawGizmos(
                self.gizmo_storage,
                &self.gizmo_interaction,
                &self.camera,
                .{ .x = window_pos.x + min_pos.x, .y = window_pos.y + min_pos.y + @as(f32, @floatFromInt(toolbar_height)) },
                size,
            );
            self.updatePushConstBlock();
        }

        self.export2dPopup.draw();

        nc.igEnd();
    }

    fn updatePushConstBlock(self: *Viewport) void {
        var forward: nm.vec3 = self.camera.target - self.camera.position;
        forward = nm.Vec3.normalize(forward);

        self.frag_push_const_block = .{
            .eye = .{
                self.camera.position[0],
                self.camera.position[1],
                self.camera.position[2],
                0.0,
            },
            .up = .{
                self.camera.up[0],
                self.camera.up[1],
                self.camera.up[2],
                0.0,
            },
            .forward = .{
                forward[0],
                forward[1],
                forward[2],
                0.0,
            },
        };
    }

    fn createDescriptorPool(self: *Viewport) void {
        const pool_size: nyan.vk.DescriptorPoolSize = .{
            .type = .combined_image_sampler,
            .descriptor_count = nyan.global_render_graph.in_flight,
        };

        self.descriptor_pool.init(&.{pool_size}, nyan.global_render_graph.in_flight);
    }

    fn allocateDescriptorSets(self: *Viewport) void {
        for (self.descriptor_sets) |*ds|
            ds.init(&self.descriptor_pool, &.{self.nyanui.vulkan_context.descriptor_set_layout.vk_ref}, 1);
    }

    fn createDescriptors(viewportTextureRes: *nyan.RGResource) void {
        const viewport_texture: *nyan.ViewportTexture = @fieldParentPtr(nyan.ViewportTexture, "rg_resource", viewportTextureRes);
        const self: *Viewport = @fieldParentPtr(Viewport, "viewport_texture", viewport_texture);

        for (viewport_texture.textures, self.descriptor_sets) |tex, *ds| {
            const descriptor_image_info: nyan.vk.DescriptorImageInfo = .{
                .sampler = tex.sampler,
                .image_view = tex.view,
                .image_layout = .shader_read_only_optimal,
            };

            ds.write(0, &.{descriptor_image_info});
        }
    }
};
