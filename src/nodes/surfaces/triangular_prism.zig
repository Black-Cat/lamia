const util = @import("../node_utils.zig");

pub const TriangularPrism: util.NodeType = .{
    .name = util.nsdf.TriangularPrism.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
    .appendGizmosFn = appendGizmos,
};

const Data = util.nsdf.TriangularPrism.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height_horizontal"),
        .name = "Horizontal Height",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height_vertical"),
        .name = "Vertical Height",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdTriangularPrism(vec3 p, vec2 h){
    \\  vec3 q = abs(p);
    \\  return max(q.z-h.y,max(q.x*.866025+p.y*.5,-p.y)-h.x*.5);
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.height_horizontal = 0.5;
    data.height_vertical = 1.0;
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

    const format: []const u8 = "float d{d} = sdTriangularPrism({s},vec2({d:.5},{d:.5}));";

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.height_horizontal,
        data.height_vertical,
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
        .size = &data.height_horizontal,
        .offset_dist = null,
        .offset_type = .direction,
        .direction_type = .static,
        .dir = .{ 0.0, 1.0, 0.0 },

        .dir_points = undefined,
        .offset_pos = undefined,
        .offset_dir = undefined,
    };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;

    gizmo.size = &data.height_vertical;
    gizmo.dir = .{ 0.0, 0.0, 1.0 };
    gizmos_storage.size_gizmos.append(gizmo) catch unreachable;
}
