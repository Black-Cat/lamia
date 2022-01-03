const util = @import("../node_utils.zig");

pub const SmoothIntersection: util.NodeType = .{
    .name = util.nsdf.SmoothIntersection.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,

    .maxChildCount = util.std.math.maxInt(usize),
};

const Data = util.nsdf.SmoothIntersection.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .name = "Smoothing",
        .offset = @offsetOf(Data, "smoothing"),
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
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.smoothing = 0.5;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, 0);

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const command: []const u8 = "d{d} = opSmoothIntersection(d{d}, d{d}, {d:.5});";
    const res: []const u8 = util.smoothCombinatorExitCommand(command, data.enter_stack, data.enter_index, ctxt, data.smoothing);

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
