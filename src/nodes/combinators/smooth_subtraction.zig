usingnamespace @import("../node_utils.zig");

pub const SmoothSubtraction: NodeType = .{
    .name = nsdf.SmoothSubtraction.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,

    .maxChildCount = std.math.maxInt(usize),
};

const Data = nsdf.SmoothSubtraction.Data;

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .name = "Smoothing",
        .offset = @byteOffsetOf(Data, "smoothing"),
    },
};

const function_defenition: []const u8 =
    \\float opSmoothSubtraction(float d1, float d2, float k){
    \\  float h = clamp(.5 - .5 * (d2 + d1) / k, 0., 1.);
    \\  return mix(d1, -d2, h) + k * h * (1. - h);
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

    const command: []const u8 = "d{d} = opSmoothSubtraction(d{d}, d{d}, {d:.5});";
    const res: []const u8 = smoothCombinatorExitCommand(command, data.enter_stack, data.enter_index, ctxt, data.smoothing);

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
