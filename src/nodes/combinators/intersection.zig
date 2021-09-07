usingnamespace @import("../node_utils.zig");

pub const Intersection: NodeType = .{
    .name = "Intersection",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    enter_index: i32,
    enter_stack: i32,
};

const properties = [_]NodeProperty{};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    buffer.* = std.mem.asBytes(data);
}
