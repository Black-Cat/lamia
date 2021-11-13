usingnamespace @import("../node_utils.zig");

pub const CappedTorus: NodeType = .{
    .name = "Capped Torus",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = struct {
    angle: f32,
    inner_radius: f32,
    outer_radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "angle"),
        .name = "Angle",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "inner_radius"),
        .name = "Inner Radius",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "outer_radius"),
        .name = "Outer Radius",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdCappedTorus(in vec3 p, in vec2 sc, in float ra, in float rb){
    \\  p.x = abs(p.x);
    \\  float k = (sc.y*p.x>sc.x*p.y) ? dot(p.xy,sc) : length(p.xy);
    \\  return sqrt(dot(p,p) + ra*ra - 2.*ra*k) - rb;
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.angle = 2.0;
    data.inner_radius = 0.4;
    data.outer_radius = 0.1;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdCappedTorus({s}, vec2({d:.5},{d:.5}),{d:.5},{d:.5});";

    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        @sin(data.angle),
        @cos(data.angle),
        data.inner_radius,
        data.outer_radius,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

pub fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: *std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}

pub fn appendGizmos(buffer: *[]u8, gizmos_storage: *GizmoStorage) void {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    gizmos_storage.size_gizmos.append(.{
        .size = &data.inner_radius,
        .offset_dist = null,
        .offset_type = .direction,
        .direction_type = .static,
        .dir = .{ 0.0, 1.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
        .offset_dir = undefined,
    }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.outer_radius,
        .offset_dist = &data.inner_radius,
        .offset_type = .direction,
        .direction_type = .static,
        .dir = .{ 0.0, 1.0, 0.0 },
        .offset_dir = .{ 0.0, 1.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
    }) catch unreachable;
}
