const util = @import("../node_utils.zig");

pub const Symmetry: util.NodeType = .{
    .name = util.nsdf.Symmetry.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = util.nsdf.Symmetry.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawAxisMaskProperty,
        .offset = @offsetOf(Data, "axis"),
        .name = "Axis",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.axis = 1;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    if (data.axis == 0)
        return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const letters: [3][]const u8 = .{
        if (data.axis & (1 << 0) != 0) "x" else "",
        if (data.axis & (1 << 1) != 0) "y" else "",
        if (data.axis & (1 << 2) != 0) "z" else "",
    };
    const temp: []const u8 = util.std.mem.concat(ctxt.allocator, u8, letters[0..]) catch unreachable;

    const format: []const u8 = "vec3 {s} = {s}; {s}.{s} = abs({s}.{s});";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        next_point,
        ctxt.cur_point_name,
        next_point,
        temp,
        ctxt.cur_point_name,
        temp,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    ctxt.allocator.free(temp);

    return res;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    if (data.axis == 0)
        ctxt.popPointName();

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}
