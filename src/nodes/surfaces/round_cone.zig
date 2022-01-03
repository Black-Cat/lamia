const util = @import("../node_utils.zig");

pub const RoundCone: util.NodeType = .{
    .name = util.nsdf.RoundCone.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.RoundCone.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "start"),
        .name = "Start",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "end"),
        .name = "End",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "start_radius"),
        .name = "Start Radius",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "end_radius"),
        .name = "End Radius",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdRoundCone(vec3 p, vec3 a, vec3 b, float r1, float r2){
    \\  vec3 ba = b - a;
    \\  float l2 = dot(ba,ba);
    \\  float rr = r1 - r2;
    \\  float a2 = l2 - rr*rr;
    \\  float il2 = 1./l2;
    \\
    \\  vec3 pa = p - a;
    \\  float y = dot(pa,ba);
    \\  float z = y - l2;
    \\  float x2 = dot2(pa*l2 - ba*y);
    \\  float y2 = y*y*l2;
    \\  float z2 = z*z*l2;
    \\
    \\  float k = sign(rr)*rr*rr*x2;
    \\  if (sign(z)*a2*z2 > k) return sqrt(x2 + z2) * il2 - r2;
    \\  if (sign(y)*a2*y2 < k) return sqrt(x2 + y2) * il2 - r1;
    \\  return (sqrt(x2*a2*il2)+y*rr)*il2 - r1;
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.start = util.nm.vec3{ 0.0, 0.0, 0.0 };
    data.end = util.nm.vec3{ 1.0, 1.0, 1.0 };
    data.start_radius = 1.0;
    data.end_radius = 0.4;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdRoundCone({s},vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5},{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.start[0],
        data.start[1],
        data.start[2],
        data.end[0],
        data.end[1],
        data.end[2],
        data.start_radius,
        data.end_radius,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

pub fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: util.std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return util.std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}

pub fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.start }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.end }) catch unreachable;

    var gizmo: util.SizeGizmo = .{
        .size = &data.start_radius,
        .offset_pos = &data.start,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.end_radius;
    gizmo.offset_pos = &data.end;
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
