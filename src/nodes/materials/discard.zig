const util = @import("../node_utils.zig");

pub const Discard: util.NodeType = .{
    .name = util.nsdf.Discard.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,

    .enterCommandFn = enterCommand,
};

const Data = util.nsdf.Lambert.Data;
const properties = [_]util.NodeProperty{};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;
    _ = buffer;

    const format: []const u8 = "discard;";

    return util.std.fmt.allocPrint(ctxt.allocator, format, .{}) catch unreachable;
}
