const util = @import("../node_utils.zig");

const info = util.nsdf.Wrinkles.info;

pub const Wrinkles: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,

    .maxChildCount = 2,
};

const Data = util.nsdf.Wrinkles.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "power"),
        .name = "Power",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "frequency"),
        .name = "Frequency",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "magnitude"),
        .name = "Magnitude",
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.power = 0.05;
    data.frequency = 35;
    data.magnitude = 7;

    buffer.* = util.std.mem.asBytes(data);
}
