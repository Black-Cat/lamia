usingnamespace @import("../node_utils.zig");

pub const SmoothIntersection: NodeType = .{
    .name = "Smooth Intersection",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = struct {
    smoothing: f32,

    enter_index: usize,
    enter_stack: usize,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .name = "Smoothing",
        .offset = @byteOffsetOf(Data, "smoothing"),
    },
};

const function_defenition: []const u8 =
    \\float opSmoothIntersection(float d1, float d2, float k){
    \\  float h = clamp(.5 - .5 * (d2 - d1) / k, 0., 1.);
    \\  return mix(d2, d1, h) + k * h * (1. - h);
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.smoothing = 0.5;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, 0);

    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "float d{d} = opSmoothIntersection(d{d}, d{d}, {d:.5});";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_stack + 2 >= ctxt.value_indexes.items.len) {
        res = std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;
    } else {
        const prev_prev_index: usize = ctxt.value_indexes.items[ctxt.value_indexes.items.len - 2].index;
        res = std.fmt.allocPrint(ctxt.allocator, format, .{
            data.enter_index,
            ctxt.last_value_set_index,
            prev_prev_index,
            data.smoothing,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
