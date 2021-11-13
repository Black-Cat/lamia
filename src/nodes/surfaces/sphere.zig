usingnamespace @import("../node_utils.zig");

pub const Sphere: NodeType = .{
    .name = "Sphere",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = struct {
    radius: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "radius"),
        .name = "Radius",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdSphere(vec3 p, float s){
    \\  return length(p) - s;
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.radius = 1.0;
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

    const format: []const u8 = "float d{d} = sdSphere({s},{d:.5});";

    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.radius,
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

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const gizmo: SizeGizmo = .{
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
