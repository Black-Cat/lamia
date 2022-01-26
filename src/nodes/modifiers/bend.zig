const util = @import("../node_utils.zig");

const info = util.nsdf.Bend.info;

pub const Bend: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
    .modifyGizmoPointsFn = modifyGizmoPoints,
};

const Data = util.nsdf.Bend.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "power"),
        .name = "Power",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.power = 1.0;

    buffer.* = util.std.mem.asBytes(data);
}

fn modifyGizmoPoints(buffer: *[]u8, points: []util.nm.vec4) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const k: f32 = data.power;

    for (points) |*p| {
        const c: f32 = @cos(k * p.*[0]);
        const s: f32 = @sin(k * p.*[0]);
        const m: util.nm.mat2x2 = .{ .{ c, s }, .{ -s, c } };
        const q: util.nm.vec2 = util.nm.Mat2x2.mulv(m, .{ p.*[0], p.*[1] });
        p.*[0] = q[0];
        p.*[1] = q[1];
    }
}
