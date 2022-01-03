const util = @import("../node_utils.zig");

pub const VerticalCappedCone: util.NodeType = .{
    .name = util.nsdf.VerticalCappedCone.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.VerticalCappedCone.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height"),
        .name = "Height",
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
    \\float sdVerticalCappedCone(vec3 p, float h, float r1, float r2){
    \\  vec2 q = vec2(length(p.xz),p.y);
    \\  vec2 k1 = vec2(r2, h);
    \\  vec2 k2 = vec2(r2 - r1, 2. * h);
    \\  vec2 ca = vec2(q.x - min(q.x, (q.y<0.)?r1:r2), abs(q.y) - h);
    \\  vec2 cb = q - k1 + k2*clamp(dot(k1-q,k2)/dot2(k2),0.,1.);
    \\  float s = (cb.x<0. && ca.y<0.) ? -1. : 1.;
    \\  return s * sqrt(min(dot2(ca), dot2(cb)));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.height = 1.0;
    data.start_radius = 1.0;
    data.end_radius = 0.4;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdVerticalCappedCone({s},{d:.5},{d:.5},{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.height,
        data.start_radius,
        data.end_radius,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

pub fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: util.std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return util.std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}

pub fn appendGizmos(buffer: *[]u8, gizmos_storage: *util.GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var gizmo: util.SizeGizmo = .{
        .size = &data.start_radius,
        .offset_dist = &data.height,
        .offset_type = .direction,
        .direction_type = .static,
        .offset_dir = .{ 0.0, -1.0, 0.0 },
        .dir = .{ 1.0, 0.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.end_radius;
    gizmo.offset_dir = .{ 0.0, 1.0, 0.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.height;
    gizmo.offset_dist = null;
    gizmo.dir = .{ 0.0, 1.0, 0.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
