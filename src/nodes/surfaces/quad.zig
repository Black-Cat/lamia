usingnamespace @import("../node_utils.zig");

pub const Quad: NodeType = .{
    .name = "Quad",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = struct {
    point_a: nm.vec3,
    point_b: nm.vec3,
    point_c: nm.vec3,
    point_d: nm.vec3,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_a"),
        .name = "Point A",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_b"),
        .name = "Point B",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_c"),
        .name = "Point C",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "point_d"),
        .name = "Point D",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdQuad(vec3 p, vec3 a, vec3 b, vec3 c, vec3 d){
    \\  vec3 ba = b - a; vec3 pa = p - a;
    \\  vec3 cb = c - b; vec3 pb = p - b;
    \\  vec3 dc = d - c; vec3 pc = p - c;
    \\  vec3 ad = a - d; vec3 pd = p - d;
    \\  vec3 nor = cross(ba, ad);
    \\  return sqrt(
    \\    (sign(dot(cross(ba,nor),pa)) +
    \\    sign(dot(cross(cb,nor),pb)) +
    \\    sign(dot(cross(dc,nor),pc)) +
    \\    sign(dot(cross(ad,nor),pd))<3.)
    \\    ?
    \\    min(min(min(
    \\    dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.,1.)-pa),
    \\    dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.,1.)-pb)),
    \\    dot2(dc*clamp(dot(dc,pc)/dot2(dc),0.,1.)-pc)),
    \\    dot2(ad*clamp(dot(ad,pd)/dot2(ad),0.,1.)-pd))
    \\    :
    \\    dot(nor,pa)*dot(nor,pa)/dot2(nor));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.point_a = .{ 0.0, 0.0, 0.0 };
    data.point_b = .{ 0.0, 1.0, 0.0 };
    data.point_c = .{ 1.0, 1.0, 0.0 };
    data.point_d = .{ 1.0, 0.0, 0.0 };
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdQuad({s},vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}));";

    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.point_a[0],
        data.point_a[1],
        data.point_a[2],
        data.point_b[0],
        data.point_b[1],
        data.point_b[2],
        data.point_c[0],
        data.point_c[1],
        data.point_c[2],
        data.point_d[0],
        data.point_d[1],
        data.point_d[2],
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

pub fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: *std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}

pub fn appendGizmos(buffer: *[]u8, gizmos_storage: *GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_a }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_b }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_c }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.point_d }) catch unreachable;
}
