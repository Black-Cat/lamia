const nyan = @import("nyancore");
const nc = nyan.c;
const std = @import("std");
const Widget = nyan.Widgets.Widget;
const Window = nyan.Widgets.Window;

pub const Viewport = struct {
    window: nyan.Widgets.Window,
    visible: bool,
    window_class: *nc.ImGuiWindowClass,

    nyanui: *nyan.UI,

    viewport_texture: nyan.ViewportTexture,
    render_pass: nyan.ScreenRenderPass,

    descriptor_pool: nyan.vk.DescriptorPool,
    descriptor_sets: []nyan.vk.DescriptorSet,

    pub fn init(self: *Viewport, comptime name: [:0]const u8, window_class: *nc.ImGuiWindowClass, nyanui: *nyan.UI) void {
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
    }

    pub fn deinit(self: *Viewport) void {}

    fn windowInit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        self.viewport_texture.init("Viewport Texture", nyan.global_render_graph.in_flight, 128, 128, nyan.app.allocator);
        self.viewport_texture.alloc();
        nyan.global_render_graph.addViewportTexture(&self.viewport_texture);

        self.render_pass.init("Viewport Render Pass", nyan.app.allocator);
        self.render_pass.rg_pass.appendReadResource(&self.viewport_texture.rg_resource);
        nyan.global_render_graph.passes.append(&self.render_pass.rg_pass) catch unreachable;

        self.createDescriptorPool();

        self.descriptor_sets = nyan.app.allocator.alloc(nyan.vk.DescriptorSet, nyan.global_render_graph.in_flight) catch unreachable;
        self.allocateDescriptorSets();

        createDescriptors(&self.viewport_texture.rg_resource);
    }

    fn windowDeinit(widget: *Widget) void {
        const window: *Window = @fieldParentPtr(Window, "widget", widget);
        const self: *Viewport = @fieldParentPtr(Viewport, "window", window);

        nyan.vkw.vkd.destroyDescriptorPool(nyan.vkw.vkc.device, self.descriptor_pool, null);
        self.viewport_texture.deinit();

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
                self.render_pass.rg_pass.appendWriteResource(&nyan.global_render_graph.final_swapchain.rg_resource);
            } else {
                self.render_pass.rg_pass.removeWriteResource(&nyan.global_render_graph.final_swapchain.rg_resource);
            }
            nyan.global_render_graph.needs_rebuilding = true;
        }

        var min_pos: nc.ImVec2 = undefined;
        var max_pos: nc.ImVec2 = undefined;
        nc.igGetWindowContentRegionMin(&min_pos);
        nc.igGetWindowContentRegionMax(&max_pos);

        var window_pos: nc.ImVec2 = undefined;
        nc.igGetWindowPos(&window_pos);

        const cur_width: u32 = @floatToInt(u32, @round(max_pos.x - min_pos.x));
        const cur_height: u32 = @floatToInt(u32, @round(max_pos.y - min_pos.y));

        if (self.visible and (cur_width != self.viewport_texture.width or cur_height != self.viewport_texture.height)) {
            self.viewport_texture.width = cur_width;
            self.viewport_texture.height = cur_height;

            self.viewport_texture.resize(&nyan.global_render_graph);
            nyan.global_render_graph.changeResourceBetweenFrames(&self.viewport_texture.rg_resource, createDescriptors);
        }

        nc.igImage(
            @ptrCast(*c_void, &self.descriptor_sets[nyan.global_render_graph.frame_index]),
            .{ .x = max_pos.x - min_pos.x, .y = max_pos.y - min_pos.y },
            .{ .x = 0, .y = 0 },
            .{ .x = 1, .y = 1 },
            .{ .x = 1, .y = 1, .z = 1, .w = 1 },
            .{ .x = 0, .y = 0, .z = 0, .w = 0 },
        );

        nc.igEnd();
    }

    fn createDescriptorPool(self: *Viewport) void {
        const pool_size: nyan.vk.DescriptorPoolSize = .{
            .type = .combined_image_sampler,
            .descriptor_count = nyan.global_render_graph.in_flight,
        };

        const descriptor_pool_info: nyan.vk.DescriptorPoolCreateInfo = .{
            .pool_size_count = 1,
            .p_pool_sizes = @ptrCast([*]const nyan.vk.DescriptorPoolSize, &pool_size),
            .max_sets = nyan.global_render_graph.in_flight,
            .flags = .{},
        };

        self.descriptor_pool = nyan.vkw.vkd.createDescriptorPool(nyan.vkw.vkc.device, descriptor_pool_info, null) catch |err| {
            nyan.vkw.printVulkanError("Couldn't create descriptor pool for viewport", err, nyan.app.allocator);
            return;
        };
    }

    fn allocateDescriptorSets(self: *Viewport) void {
        for (self.descriptor_sets) |*ds| {
            const descriptor_set_allocate_info: nyan.vk.DescriptorSetAllocateInfo = .{
                .descriptor_pool = self.descriptor_pool,
                .p_set_layouts = @ptrCast([*]const nyan.vk.DescriptorSetLayout, &self.nyanui.vulkan_context.descriptor_set_layout),
                .descriptor_set_count = 1,
            };

            nyan.vkw.vkd.allocateDescriptorSets(nyan.vkw.vkc.device, descriptor_set_allocate_info, @ptrCast([*]nyan.vk.DescriptorSet, ds)) catch |err| {
                nyan.vkw.printVulkanError("Can't allocate descriptor set for viewport", err, nyan.app.allocator);
                return;
            };
        }
    }

    fn createDescriptors(viewportTextureRes: *nyan.RGResource) void {
        const viewport_texture: *nyan.ViewportTexture = @fieldParentPtr(nyan.ViewportTexture, "rg_resource", viewportTextureRes);
        const self: *Viewport = @fieldParentPtr(Viewport, "viewport_texture", viewport_texture);

        for (viewport_texture.textures) |tex, ind| {
            const descriptor_image_info: nyan.vk.DescriptorImageInfo = .{
                .sampler = tex.sampler,
                .image_view = tex.view,
                .image_layout = .shader_read_only_optimal,
            };

            const write_descriptor_set: nyan.vk.WriteDescriptorSet = .{
                .dst_set = self.descriptor_sets[ind],
                .descriptor_type = .combined_image_sampler,
                .dst_binding = 0,
                .p_image_info = @ptrCast([*]const nyan.vk.DescriptorImageInfo, &descriptor_image_info),
                .descriptor_count = 1,

                .p_buffer_info = undefined,
                .p_texel_buffer_view = undefined,
                .dst_array_element = 0,
            };

            nyan.vkw.vkd.updateDescriptorSets(nyan.vkw.vkc.device, 1, @ptrCast([*]const nyan.vk.WriteDescriptorSet, &write_descriptor_set), 0, undefined);
        }
    }
};
