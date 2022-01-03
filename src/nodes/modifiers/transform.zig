const util = @import("../node_utils.zig");

pub const Transform: util.NodeType = .{
    .name = util.nsdf.Transform.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,

    .has_edit_callback = true,
    .edit_callback = editCallback,

    .modifyGizmoPointsFn = modifyGizmoPoints,
};

const Data = util.nsdf.Transform.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "rotation"),
        .name = "Rotation",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "translation"),
        .name = "Translation",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.rotation = util.nm.Vec3.zeros();
    data.translation = util.nm.Vec3.zeros();
    data.transform_matrix = util.nm.Mat4x4.identity();

    buffer.* = util.std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.transform_matrix = util.nm.Mat4x4.identity();
    util.nm.Transform.rotateX(&data.transform_matrix, -data.rotation[0]);
    util.nm.Transform.rotateY(&data.transform_matrix, -data.rotation[1]);
    util.nm.Transform.rotateZ(&data.transform_matrix, -data.rotation[2]);
    util.nm.Transform.translate(&data.transform_matrix, -data.translation);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const temp: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "mat4({d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5})", .{
        data.transform_matrix[0][0],
        data.transform_matrix[0][1],
        data.transform_matrix[0][2],
        data.transform_matrix[0][3],
        data.transform_matrix[1][0],
        data.transform_matrix[1][1],
        data.transform_matrix[1][2],
        data.transform_matrix[1][3],
        data.transform_matrix[2][0],
        data.transform_matrix[2][1],
        data.transform_matrix[2][2],
        data.transform_matrix[2][3],
        data.transform_matrix[3][0],
        data.transform_matrix[3][1],
        data.transform_matrix[3][2],
        data.transform_matrix[3][3],
    }) catch unreachable;

    const format: []const u8 = "vec3 {s} = ({s} * vec4({s}, 1.)).xyz;";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        temp,
        ctxt.cur_point_name,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    ctxt.allocator.free(temp);

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

    const inv: util.nm.mat4x4 = util.nm.Mat4x4.inverse(data.transform_matrix);

    for (points) |*p|
        p.* = util.nm.Mat4x4.mulv(inv, p.*);
}
