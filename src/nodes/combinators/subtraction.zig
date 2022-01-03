const util = @import("../node_utils.zig");

pub const Subtraction: util.NodeType = .{
    .name = util.nsdf.Subtraction.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,

    .maxChildCount = util.std.math.maxInt(usize),
};

const Data = util.nsdf.Subtraction.Data;

const properties = [_]util.NodeProperty{};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

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

    const command: []const u8 = "d{d} = max(d{d}, -d{d});";
    const res: []const u8 = util.combinatorExitCommand(command, data.enter_stack, data.enter_index, ctxt);

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
