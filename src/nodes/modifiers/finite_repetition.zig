const util = @import("../node_utils.zig");

pub const FiniteRepetition: util.NodeType = .{
    .name = util.nsdf.FiniteRepetition.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = util.nsdf.FiniteRepetition.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "period"),
        .name = "Period",
    },
    .{
        .drawFn = util.prop.drawFloat3Property,
        .offset = @offsetOf(Data, "size"),
        .name = "Size",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.period = 2.0;
    data.size = [_]f32{ 3.0, 3.0, 3.0 };

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = {s} - {d:.5} * clamp(round({s}/{d:.5}), -vec3({d:.5},{d:.5},{d:.5}), vec3({d:.5},{d:.5},{d:.5}));";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        ctxt.cur_point_name,
        data.period,
        ctxt.cur_point_name,
        data.period,
        data.size[0],
        data.size[1],
        data.size[2],
        data.size[0],
        data.size[1],
        data.size[2],
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = buffer;

    ctxt.popPointName();
    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}
