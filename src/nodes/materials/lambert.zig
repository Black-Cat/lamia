const util = @import("../node_utils.zig");

const info = util.nsdf.Lambert.info;

pub const Lambert: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,

    .enter_command_fn = info.enter_command_fn,
};

const Data = util.nsdf.Lambert.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawColor3Property,
        .offset = @offsetOf(Data, "color"),
        .name = "Color",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.color = [3]f32{ 0.8, 0.8, 0.8 };

    buffer.* = util.std.mem.asBytes(data);
}
