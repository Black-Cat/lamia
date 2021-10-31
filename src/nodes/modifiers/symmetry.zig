usingnamespace @import("../node_utils.zig");

pub const Symmetry: NodeType = .{
    .name = "Symmetry",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = struct {
    axis: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawAxisMaskProperty,
        .offset = @byteOffsetOf(Data, "axis"),
        .name = "Axis",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.axis = 1;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    if (data.axis == 0)
        return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;

    const next_point: []const u8 = std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const letters: [3][]const u8 = .{
        if (data.axis & (1 << 0) != 0) "x" else "",
        if (data.axis & (1 << 1) != 0) "y" else "",
        if (data.axis & (1 << 2) != 0) "z" else "",
    };
    const temp: []const u8 = std.mem.concat(ctxt.allocator, u8, letters[0..]) catch unreachable;

    const format: []const u8 = "vec3 {s} = {s}; {s}.{s} = abs({s}.{s});";
    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
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

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    if (data.axis == 0)
        ctxt.popPointName();

    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}
