const util = @import("../node_utils.zig");

pub const Octahedron: util.NodeType = .{
    .name = util.nsdf.Octahedron.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.Octahedron.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "radius"),
        .name = "Radius",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdOctahedron(vec3 p, float s){
    \\  p = abs(p);
    \\  float m = p.x+p.y+p.z-s;
    \\  vec3 q;
    \\  if (3.*p.x < m) q = p.xyz;
    \\  else if (3.*p.y < m) q = p.yzx;
    \\  else if (3.*p.z < m) q = p.zxy;
    \\  else return m*.57735027;
    \\  float k = clamp(.5*(q.z-q.y+s),0.,s);
    \\  return length(vec3(q.x,q.y-s+k,q.z-k));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.radius = 1.0;
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

    const format: []const u8 = "float d{d} = sdOctahedron({s},{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.radius,
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
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const gizmo: util.SizeGizmo = .{
            .size = &data.radius,
            .dir = .{
                @intToFloat(f32, @boolToInt(i == 0)),
                @intToFloat(f32, @boolToInt(i == 1)),
                @intToFloat(f32, @boolToInt(i == 2)),
            },
            .offset_dist = null,
            .offset_type = .direction,
            .direction_type = .static,

            .dir_points = undefined,
            .offset_dir = undefined,
            .offset_pos = undefined,
        };
        gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
    }
}
