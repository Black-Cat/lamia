const util = @import("../node_utils.zig");

pub const Bend: util.NodeType = .{
    .name = util.nsdf.Bend.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
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

const function_defenition: []const u8 =
    \\vec3 opBend(vec3 p, float k){
    \\  float c = cos(k*p.x);
    \\  float s = sin(k*p.x);
    \\  mat2 m = mat2(c, -s, s, c);
    \\  vec3 q = vec3(m * p.xy, p.z);
    \\  return q;
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.power = 1.0;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = opBend({s}, {d:.5});";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{ next_point, ctxt.cur_point_name, data.power }) catch unreachable;

    ctxt.pushPointName(next_point);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    ctxt.popPointName();
    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
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
