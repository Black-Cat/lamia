usingnamespace @import("../node_utils.zig");

pub const EnvironmentSettings: NodeType = .{
    .name = "Environment Settings",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    background_color: [3]f32,
    light_dir: [3]f32,
    shadow_steps: u32,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.background_color = [_]f32{ 0.281, 0.281, 0.281 };
    data.light_dir = [_]f32{ 0.57, 0.57, 0.57 };
    data.shadow_steps = 16;

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
