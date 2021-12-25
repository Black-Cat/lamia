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

usingnamespace nyan.file_util;

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
        defer nyan.vkw.vkd.destroyShaderModule(nyan.vkw.vkc.device, shader, null);

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
        var render_pass: nyan.ScreenRenderPass = undefined;
        render_pass.init(
            "Export 2D Render Pass",
            nyan.app.allocator,
            &tex,
            &shader,
            @sizeOf(FragPushConstBlock),
            self.viewport_push_block,
            .transfer_src_optimal,
        );
        defer render_pass.deinit();

        render_pass.rg_pass.initFn(&render_pass.rg_pass);
        defer render_pass.rg_pass.deinitFn(&render_pass.rg_pass);

        // Use render pass
        const command_buffer: nyan.vk.CommandBuffer = nyan.global_render_graph.allocateCommandBuffer();
        nyan.global_render_graph.beginSingleTimeCommands(command_buffer);
        render_pass.rg_pass.renderFn(&render_pass.rg_pass, command_buffer, 0);

        // Copy image to buffer
        const tex_size: usize = @intCast(usize, 4 * tex.width * tex.height);

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

        var staging_buffer: nyan.vk.Buffer = nyan.vkw.vkd.createBuffer(nyan.vkw.vkc.device, buffer_info, null) catch |err| {
            nyan.vkw.printVulkanError("Can't crete buffer for export 2d texture", err, nyan.vkw.vkc.allocator);
            return;
        };
        defer nyan.vkw.vkd.destroyBuffer(nyan.vkw.vkc.device, staging_buffer, null);

        var mem_req: nyan.vk.MemoryRequirements = nyan.vkw.vkd.getBufferMemoryRequirements(nyan.vkw.vkc.device, staging_buffer);

        const alloc_info: nyan.vk.MemoryAllocateInfo = .{
            .allocation_size = mem_req.size,
            .memory_type_index = nyan.vkw.vkc.getMemoryType(mem_req.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        var staging_buffer_memory: nyan.vk.DeviceMemory = nyan.vkw.vkd.allocateMemory(nyan.vkw.vkc.device, alloc_info, null) catch |err| {
            nyan.vkw.printVulkanError("Can't allocate buffer for export 2d texture", err, nyan.vkw.vkc.allocator);
            return;
        };
        defer nyan.vkw.vkd.freeMemory(nyan.vkw.vkc.device, staging_buffer_memory, null);

        nyan.vkw.vkd.bindBufferMemory(nyan.vkw.vkc.device, staging_buffer, staging_buffer_memory, 0) catch |err| {
            nyan.vkw.printVulkanError("Can't bind buffer memory for export 2d texture", err, nyan.vkw.vkc.allocator);
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

        nyan.vkw.vkd.cmdPipelineBarrier(
            command_buffer,
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
            .image_extent = .{
                .width = @intCast(u32, tex.width),
                .height = @intCast(u32, tex.height),
                .depth = 1,
            },
        };

        nyan.vkw.vkd.cmdCopyImageToBuffer(command_buffer, tex.textures[0].image, .transfer_src_optimal, staging_buffer, 1, @ptrCast([*]const nyan.vk.BufferImageCopy, &region));
        nyan.global_render_graph.endSingleTimeCommands(command_buffer);
        nyan.global_render_graph.submitCommandBuffer(command_buffer);

        var mapped_memory: *c_void = nyan.vkw.vkd.mapMemory(nyan.vkw.vkc.device, staging_buffer_memory, 0, tex_size, .{}) catch |err| {
            nyan.vkw.printVulkanError("Can't map memory for export 2d texture", err, nyan.vkw.vkc.allocator);
            return;
        } orelse return;
        defer nyan.vkw.vkd.unmapMemory(nyan.vkw.vkc.device, staging_buffer_memory);

        // Write buffer to path
        const path: []const u8 = std.mem.sliceTo(&self.selected_file_path, 0);
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.createFile(path, .{ .read = true, .truncate = true }) catch |err| {
            nyan.printError("Export 2D", "Can't create a file");
            return;
        };
        defer file.close();

        // BMP Header
        file.writeAll("\x42\x4D") catch unreachable;
        writeU32Little(&file, 122 + tex_size) catch unreachable;
        file.writeAll("\x00\x00\x00\x00\x7A\x00\x00\x00") catch unreachable;

        // DIB Header
        file.writeAll("\x6C\x00\x00\x00") catch unreachable;
        writeI32Little(&file, @intCast(i32, tex.width)) catch unreachable;
        writeI32Little(&file, -@intCast(i32, tex.height)) catch unreachable;
        file.writeAll("\x01\x00\x20\x00\x03\x00\x00\x00") catch unreachable;
        writeU32Little(&file, tex_size) catch unreachable;
        file.writeAll("\x13\x0B\x00\x00\x13\x0B\x00\x00") catch unreachable;
        file.writeAll("\x00\x00\x00\x00\x00\x00\x00\x00") catch unreachable;
        file.writeAll("\x00\x00\xFF\x00") catch unreachable;
        file.writeAll("\x00\xFF\x00\x00") catch unreachable;
        file.writeAll("\xFF\x00\x00\x00") catch unreachable;
        file.writeAll("\x00\x00\x00\xFF") catch unreachable;
        file.writeAll("\x20\x6E\x69\x57") catch unreachable;
        file.writeAll("\x00" ** 36) catch unreachable;

        // Pixel Array
        var buf: []u8 = undefined;
        buf.ptr = @ptrCast([*]u8, mapped_memory);
        buf.len = tex_size;
        file.writeAll(buf) catch unreachable;
    }
};
