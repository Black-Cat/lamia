const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;

const Global = @import("../../global.zig");

const Camera = @import("../../scene/camera.zig").Camera;
const CameraSettings = @import("../../nodes/scene_settings/camera_settings.zig").Data;
const EnvironmentSettings = @import("../../nodes/scene_settings/environment_settings.zig").Data;

const FragPushConstBlock = @import("viewport.zig").FragPushConstBlock;
const RootType = @import("../../scene/scene.zig").RootType;
const SceneNode = @import("../../scene/scene_node.zig").SceneNode;
const node_collection = @import("../../nodes/node_collection.zig");
const scene2shader = @import("../../scene/scene2shader.zig").scene2shader;

pub const Export2dPopup = struct {
    pub const name = "Export 2D";
    const file_path_len = 256;

    camera: *Camera,
    selected_file_path: [file_path_len]u8,
    viewport_push_block: *FragPushConstBlock,

    width: u32,
    height: u32,
    overwrite_camera_settings: CameraSettings,
    overwrite_environment_settings: EnvironmentSettings,

    pub fn init(self: *Export2dPopup, camera: *Camera, width: u32, height: u32, viewport_push_block: *FragPushConstBlock) void {
        self.camera = camera;
        @memcpy(@ptrCast([*]u8, &self.selected_file_path[0]), "", 1);

        self.width = width;
        self.height = height;
        self.viewport_push_block = viewport_push_block;

        const camera_settings: *CameraSettings = @ptrCast(*CameraSettings, @alignCast(@alignOf(*CameraSettings), Global.main_scene.camera_settings.buffer.ptr));
        self.overwrite_camera_settings = camera_settings.*;

        const environment_settings: *EnvironmentSettings = @ptrCast(*EnvironmentSettings, @alignCast(@alignOf(*EnvironmentSettings), Global.main_scene.environment_settings.buffer.ptr));
        self.overwrite_environment_settings = environment_settings.*;

        nc.igOpenPopup(name, nc.ImGuiPopupFlags_None);
    }

    pub fn draw(self: *Export2dPopup) void {
        var open_modal: bool = true;
        if (!nc.igBeginPopupModal(name, &open_modal, nc.ImGuiWindowFlags_AlwaysAutoResize))
            return;

        if (nc.igInputText("Path", @ptrCast([*c]u8, &self.selected_file_path), file_path_len, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
            self.export2d();
            nc.igCloseCurrentPopup();
        }

        _ = nc.igInputScalar("Width", nc.ImGuiDataType_U32, &self.width, null, null, null, nc.ImGuiInputTextFlags_None);
        _ = nc.igInputScalar("Height", nc.ImGuiDataType_U32, &self.height, null, null, null, nc.ImGuiInputTextFlags_None);
        _ = nc.igInputScalar("Steps", nc.ImGuiDataType_U32, &self.overwrite_camera_settings.steps, null, null, null, nc.ImGuiInputTextFlags_None);
        _ = nc.igInputScalar("Shadow Steps", nc.ImGuiDataType_U32, &self.overwrite_environment_settings.shadow_steps, null, null, null, nc.ImGuiInputTextFlags_None);
        _ = nc.igInputFloat("Near", &self.overwrite_camera_settings.near, 0.0, 0.0, "%.3f", nc.ImGuiInputTextFlags_None);
        _ = nc.igInputFloat("Far", &self.overwrite_camera_settings.far, 0.0, 0.0, "%.3f", nc.ImGuiInputTextFlags_None);

        if (nc.igButton("Export", .{ .x = 0, .y = 0 })) {
            self.export2d();
            nc.igCloseCurrentPopup();
        }

        nc.igSameLine(260.0, 2.0);
        if (nc.igButton("Cancel", .{ .x = 0, .y = 0 }))
            nc.igCloseCurrentPopup();

        nc.igEndPopup();
    }

    fn export2d(self: *Export2dPopup) void {
        // Create settings
        var settings_node: SceneNode = undefined;
        settings_node.init(&RootType, "Export Settings", null);
        defer settings_node.deinit();

        for (node_collection.scene_settings) |*node_type| {
            var node: *SceneNode = settings_node.add();
            node.init(node_type, node_type.name, &settings_node);

            if (std.mem.eql(u8, node_type.name, "Camera Settings")) {
                const camera_settings: *CameraSettings = @ptrCast(*CameraSettings, @alignCast(@alignOf(*CameraSettings), node.buffer.ptr));
                camera_settings.* = self.overwrite_camera_settings;
            } else if (std.mem.eql(u8, node_type.name, "Environment Settings")) {
                const environment_settings: *EnvironmentSettings = @ptrCast(*EnvironmentSettings, @alignCast(@alignOf(*EnvironmentSettings), node.buffer.ptr));
                environment_settings.* = self.overwrite_environment_settings;
            }
        }

        // Create shader
        var shader: nyan.vk.ShaderModule = scene2shader(&Global.main_scene, &settings_node);
        defer nyan.vkfn.d.destroyShaderModule(nyan.vkctxt.device, shader, null);

        // Create texture
        const image_format: nyan.vk.Format = nyan.global_render_graph.final_swapchain.image_format;
        var tex: nyan.ViewportTexture = undefined;
        tex.init("Export Texture", 1, self.width, self.height, image_format, nyan.app.allocator);
        tex.usage = .{
            .color_attachment_bit = true,
            .transfer_src_bit = true,
        };
        tex.image_layout = .@"undefined";
        tex.alloc();
        defer tex.deinit();

        // Create render pass
        var render_pass: nyan.ScreenRenderPass(nyan.ViewportTexture) = undefined;
        render_pass.init(
            "Export 2D Render Pass",
            &tex,
            &shader,
            @sizeOf(FragPushConstBlock),
            self.viewport_push_block,
        );
        defer render_pass.deinit();

        var framebuffer_index: u32 = 0;
        render_pass.render_pass.framebuffer_index = &framebuffer_index;

        render_pass.rg_pass.final_layout = .transfer_src_optimal;

        render_pass.rg_pass.initFn(&render_pass.rg_pass);
        defer render_pass.rg_pass.deinitFn(&render_pass.rg_pass);

        // Use render pass
        var scb: nyan.SingleCommandBuffer = nyan.SingleCommandBuffer.allocate(&nyan.global_render_graph.command_pool) catch unreachable;
        scb.command_buffer.beginSingleTimeCommands();
        render_pass.rg_pass.renderFn(&render_pass.rg_pass, &scb.command_buffer, 0);

        // Copy image to buffer
        const tex_size: usize = @intCast(usize, 4 * tex.extent.width * tex.extent.height);

        const buffer_info: nyan.vk.BufferCreateInfo = .{
            .size = tex_size,
            .usage = .{
                .transfer_dst_bit = true,
            },
            .sharing_mode = .exclusive,
            .flags = .{},
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        var staging_buffer: nyan.vk.Buffer = nyan.vkfn.d.createBuffer(nyan.vkctxt.device, buffer_info, null) catch |err| {
            nyan.printVulkanError("Can't crete buffer for export 2d texture", err);
            return;
        };
        defer nyan.vkfn.d.destroyBuffer(nyan.vkctxt.device, staging_buffer, null);

        var mem_req: nyan.vk.MemoryRequirements = nyan.vkfn.d.getBufferMemoryRequirements(nyan.vkctxt.device, staging_buffer);

        const alloc_info: nyan.vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = nyan.vkctxt.getMemoryType(mem_req.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        var staging_buffer_memory: nyan.vk.DeviceMemory = nyan.vkfn.d.allocateMemory(nyan.vkctxt.device, alloc_info, null) catch |err| {
            nyan.printVulkanError("Can't allocate buffer for export 2d texture", err);
            return;
        };
        defer nyan.vkfn.d.freeMemory(nyan.vkctxt.device, staging_buffer_memory, null);

        nyan.vkfn.d.bindBufferMemory(nyan.vkctxt.device, staging_buffer, staging_buffer_memory, 0) catch |err| {
            nyan.printVulkanError("Can't bind buffer memory for export 2d texture", err);
            return;
        };

        const image_memory_barrier: nyan.vk.ImageMemoryBarrier = .{
            .src_access_mask = .{ .color_attachment_write_bit = true },
            .dst_access_mask = .{ .transfer_read_bit = true },
            .old_layout = .transfer_src_optimal,
            .new_layout = .transfer_src_optimal,
            .src_queue_family_index = nyan.vk.QUEUE_FAMILY_IGNORED,
            .dst_queue_family_index = nyan.vk.QUEUE_FAMILY_IGNORED,
            .image = tex.textures[0].image,
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
                .level_count = 1,
            },
        };

        nyan.vkfn.d.cmdPipelineBarrier(
            scb.command_buffer.vk_ref,
            .{ .color_attachment_output_bit = true },
            .{ .transfer_bit = true },
            .{},
            0,
            undefined,
            0,
            undefined,
            1,
            @ptrCast([*]const nyan.vk.ImageMemoryBarrier, &image_memory_barrier),
        );

        const region: nyan.vk.BufferImageCopy = .{
            .buffer_offset = 0,
            .buffer_row_length = 0,
            .buffer_image_height = 0,
            .image_subresource = .{
                .aspect_mask = .{ .color_bit = true },
                .mip_level = 0,
                .base_array_layer = 0,
                .layer_count = 1,
            },
            .image_offset = .{ .x = 0, .y = 0, .z = 0 },
            .image_extent = tex.textures[0].extent,
        };

        nyan.vkfn.d.cmdCopyImageToBuffer(scb.command_buffer.vk_ref, tex.textures[0].image, .transfer_src_optimal, staging_buffer, 1, @ptrCast([*]const nyan.vk.BufferImageCopy, &region));
        scb.command_buffer.endSingleTimeCommands();
        scb.submit(nyan.vkctxt.graphics_queue);

        var mapped_memory: *anyopaque = nyan.vkfn.d.mapMemory(nyan.vkctxt.device, staging_buffer_memory, 0, tex_size, .{}) catch |err| {
            nyan.printVulkanError("Can't map memory for export 2d texture", err);
            return;
        } orelse return;
        defer nyan.vkfn.d.unmapMemory(nyan.vkctxt.device, staging_buffer_memory);

        // Write buffer to path
        const path: []const u8 = std.mem.sliceTo(&self.selected_file_path, 0);
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.createFile(path, .{ .read = true, .truncate = true }) catch {
            nyan.printError("Export 2D", "Can't create a file");
            return;
        };
        defer file.close();
        const writer = file.writer();

        var image: nyan.Image = .{
            .width = tex.extent.width,
            .height = tex.extent.height,
            .data = @ptrCast([*]u8, mapped_memory)[0..tex_size],
        };

        nyan.bmp.write(writer, image) catch {};
    }
};
