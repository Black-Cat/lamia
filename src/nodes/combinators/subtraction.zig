usingnamespace @import("../node_utils.zig");

pub const Subtraction: NodeType = .{
    .name = nsdf.Subtraction.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,

    .maxChildCount = std.math.maxInt(usize),
};

const Data = nsdf.Subtraction.Data;

const properties = [_]NodeProperty{};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

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

    const command: []const u8 = "d{d} = max(d{d}, -d{d});";
    const res: []const u8 = combinatorExitCommand(command, data.enter_stack, data.enter_index, ctxt);

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
