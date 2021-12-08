usingnamespace @import("../node_utils.zig");

pub const CappedCone: NodeType = .{
    .name = "Capped Cone",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = nsdf.CappedCone.Data;

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "start"),
        .name = "Start",
    },
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "end"),
        .name = "End",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "start_radius"),
        .name = "Start Radius",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "end_radius"),
        .name = "End Radius",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdCappedCone(vec3 p, vec3 a, vec3 b, float ra, float rb){
    \\  float rba = rb - ra;
    \\  float baba = dot(b-a,b-a);
    \\  float papa = dot(p-a,p-a);
    \\  float paba = dot(p-a,b-a)/baba;
    \\  float x = sqrt(papa - paba*paba*baba);
    \\  float cax = max(0.,x-((paba<.5)?ra:rb));
    \\  float cay = abs(paba-.5)-.5;
    \\  float k = rba*rba + baba;
    \\  float f = clamp((rba*(x-ra)+paba*baba)/k,0.,1.);
    \\  float cbx = x-ra-f*rba;
    \\  float cby = paba - f;
    \\  float s = (cbx < 0. && cay < 0.) ? -1. : 1.;
    \\  return s * sqrt(min(cax*cax + cay*cay*baba, cbx*cbx + cby*cby*baba));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.start = .{ 0.0, 0.0, 0.0 };
    data.end = .{ 1.0, 1.0, 1.0 };
    data.start_radius = 1.0;
    data.end_radius = 0.4;
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

    const format: []const u8 = "float d{d} = sdCappedCone({s}, vec3({d:.5},{d:.5},{d:.5}),vec3({d:.5},{d:.5},{d:.5}),{d:.5},{d:.5});";

    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
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

    gizmos_storage.translation_gizmos.append(.{ .pos = &data.start }) catch unreachable;
    gizmos_storage.translation_gizmos.append(.{ .pos = &data.end }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.start_radius,
        .offset_pos = &data.start,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;

    gizmos_storage.size_gizmos.append(.{
        .size = &data.end_radius,
        .offset_pos = &data.end,
        .offset_type = .position,
        .direction_type = .cross,
        .dir_points = .{ &data.start, &data.end },

        .dir = undefined,
        .offset_dist = undefined,
        .offset_dir = undefined,
    }) catch unreachable;
}
