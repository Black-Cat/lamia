usingnamespace @import("../node_utils.zig");

pub const EnvironmentSettings: NodeType = .{
    .name = "Environment Settings",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    background_color: [3]f32,
    light_dir: [3]f32,
    shadow_steps: u32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawColor3Property,
        .offset = @byteOffsetOf(Data, "background_color"),
        .name = "Background Color",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "light_dir"),
        .name = "Light Direction",
    },
    .{
        .drawFn = drawU32Property,
        .offset = @byteOffsetOf(Data, "shadow_steps"),
        .name = "Shadow Steps",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.background_color = [_]f32{ 0.281, 0.281, 0.281 };
    data.light_dir = [_]f32{ 0.57, 0.57, 0.57 };
    data.shadow_steps = 16;

    buffer.* = std.mem.asBytes(data);
}
