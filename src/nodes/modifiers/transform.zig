usingnamespace @import("../node_utils.zig");

pub const Transform: NodeType = .{
    .name = "Transform",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,

    .has_edit_callback = true,
    .edit_callback = editCallback,

    .modifyGizmoPointsFn = modifyGizmoPoints,
};

const Data = nsdf.Transform.Data;

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "rotation"),
        .name = "Rotation",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "translation"),
        .name = "Translation",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.rotation = nm.Vec3.zeros();
    data.translation = nm.Vec3.zeros();
    data.transform_matrix = nm.Mat4x4.identity();

    buffer.* = std.mem.asBytes(data);
}

fn editCallback(buffer: *[]u8) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.transform_matrix = nm.Mat4x4.identity();
    nm.Transform.rotateX(&data.transform_matrix, -data.rotation[0]);
    nm.Transform.rotateY(&data.transform_matrix, -data.rotation[1]);
    nm.Transform.rotateZ(&data.transform_matrix, -data.rotation[2]);
    nm.Transform.translate(&data.transform_matrix, -data.translation);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const temp: []const u8 = std.fmt.allocPrint(ctxt.allocator, "mat4({d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5}, {d:.5},{d:.5},{d:.5},{d:.5})", .{
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
    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        temp,
        ctxt.cur_point_name,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    ctxt.allocator.free(temp);

    return res;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    ctxt.popPointName();
    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn modifyGizmoPoints(buffer: *[]u8, points: []nm.vec4) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const inv: nm.mat4x4 = nm.Mat4x4.inverse(data.transform_matrix);

    for (points) |*p|
        p.* = nm.Mat4x4.mulv(inv, p.*);
}
