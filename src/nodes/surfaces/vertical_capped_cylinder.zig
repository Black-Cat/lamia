const util = @import("../node_utils.zig");

pub const VerticalCappedCylinder: util.NodeType = .{
    .name = util.nsdf.VerticalCappedCylinder.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.VerticalCappedCylinder.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height"),
        .name = "Height",
    },
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
    \\float sdVerticalCappedCylinder(vec3 p, float h, float r) {
    \\  vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r,h);
    \\  return min(max(d.x,d.y),0.) + length(max(d,0.));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.height = 1.0;
    data.radius = 0.5;
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

    const format: []const u8 = "float d{d} = sdVerticalCappedCylinder({s},{d:.5},{d:.5});";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.height,
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
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    var gizmo: util.SizeGizmo = .{
        .size = &data.height,
        .offset_type = .direction,
        .direction_type = .static,
        .dir = .{ 0.0, 1.0, 0.0 },
        .offset_dist = null,

        .offset_dir = undefined,
        .dir_points = undefined,
        .offset_pos = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.radius;
    gizmo.dir = .{ 1.0, 0.0, 0.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
