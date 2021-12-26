usingnamespace @import("../node_utils.zig");

pub const Scale: NodeType = .{
    .name = nsdf.Scale.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = nsdf.Scale.Data;

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "scale"),
        .name = "Scale",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.scale = 1.5;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const next_point: []const u8 = std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = {s} / {d:.5};";
    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        ctxt.cur_point_name,
        data.scale,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, 0);

    return res;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    ctxt.popPointName();

    const format: []const u8 = "float d{d} = d{d} * {d:.5};";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_index == ctxt.last_value_set_index) {
        res = std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;
    } else {
        res = std.fmt.allocPrint(ctxt.allocator, format, .{
            data.enter_index,
            ctxt.last_value_set_index,
            data.scale,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
