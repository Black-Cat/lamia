const util = @import("../node_utils.zig");

pub const SmoothUnion: util.NodeType = .{
    .name = util.nsdf.SmoothUnion.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheck,

    .maxChildCount = 2,
};

const Data = util.nsdf.SmoothUnion.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .name = "Smoothing",
        .offset = @offsetOf(Data, "smoothing"),
    },
};

const function_defenition: []const u8 =
    \\float opSmoothUnion(float d1, float d2, float k){
    \\  float h = clamp(.5 + .5 * (d2 - d1) / k, 0., 1.);
    \\  return mix(d2, d1, h) - k * h * (1. - h);
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.smoothing = 0.5;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, -@intCast(i32, iter));

    data.mats[0] = @intCast(i32, mat_offset);
    data.mats[1] = @intCast(i32, mat_offset);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "float d{d} = opSmoothUnion(d{d}, d{d}, {d:.5});";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_stack + 2 >= ctxt.value_indexes.items.len) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;

        data.mats[0] = 0;
        data.mats[1] = 0;
        data.dist_indexes[0] = data.enter_index;
        data.dist_indexes[1] = data.enter_index;
    } else {
        const prev_info: util.IterationContext.StackInfo = ctxt.value_indexes.items[ctxt.value_indexes.items.len - 1];
        const prev_prev_info: util.IterationContext.StackInfo = ctxt.value_indexes.items[ctxt.value_indexes.items.len - 2];

        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            data.enter_index,
            ctxt.last_value_set_index,
            prev_prev_info.index,
            data.smoothing,
        }) catch unreachable;

        data.mats[0] = data.mats[0] * @boolToInt(prev_info.material >= 0) + prev_info.material;
        data.mats[1] = data.mats[1] * @boolToInt(prev_prev_info.material >= 0) + prev_prev_info.material;
        data.dist_indexes[0] = prev_info.index;
        data.dist_indexes[1] = prev_prev_info.index;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

fn appendMatCheck(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: util.std.mem.Allocator) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format_mat: []const u8 = "matToColor({d}.,l,n,v)";
    const format_gen_mat: []const u8 = "m{d}";

    var mat_str: [2][]const u8 = .{undefined} ** 2;
    for (mat_str) |_, ind| {
        if (data.mats[ind] >= 0) {
            mat_str[ind] = util.std.fmt.allocPrint(allocator, format_mat, .{data.mats[ind]}) catch unreachable;
        } else {
            mat_str[ind] = util.std.fmt.allocPrint(allocator, format_gen_mat, .{-data.mats[ind]}) catch unreachable;
        }
    }

    const format: []const u8 = "{s}vec3 m{d} = mix({s},{s},d{d}/(d{d}+d{d}));if(d{d}<MAP_EPS)return m{d};";

    const res: []const u8 = util.std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        mat_str[0],
        mat_str[1],
        data.dist_indexes[0],
        data.dist_indexes[0],
        data.dist_indexes[1],
        data.enter_index,
        data.enter_index,
    }) catch unreachable;

    for (mat_str) |s|
        allocator.free(s);

    return res;
}
