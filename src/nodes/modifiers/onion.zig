const util = @import("../node_utils.zig");

pub const Onion: util.NodeType = .{
    .name = util.nsdf.Onion.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = util.nsdf.Onion.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "thickness"),
        .name = "Thickness",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.thickness = 0.2;

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

    const format: []const u8 = "float d{d} = abs(d{d}) - {d:.5};";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_index == ctxt.last_value_set_index) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;
    } else {
        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            data.enter_index,
            ctxt.last_value_set_index,
            data.thickness,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
