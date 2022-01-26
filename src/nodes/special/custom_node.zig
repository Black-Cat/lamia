const util = @import("../node_utils.zig");

const info = util.nsdf.CustomNode.info;

pub const CustomNode: util.NodeType = .{
    .name = info.name,
    .function_definition = info.function_definition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enter_command_fn = info.enter_command_fn,
    .exit_command_fn = info.exit_command_fn,
};

const Data = util.nsdf.CustomNode.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawHelpProperty,
        .offset = undefined,
        .name = 
        \\Point variables:
        \\    vec3 cpin - Custom Point Input
        \\    vec3 cpout - Custom Point Output
        ,
    },
    .{
        .drawFn = util.prop.drawCodeProperty,
        .offset = @offsetOf(Data, "enter_function"),
        .name = "Point Code",
        .prop_len = Data.max_func_len,
    },
    .{
        .drawFn = util.prop.drawHelpProperty,
        .offset = undefined,
        .name = 
        \\Distance variables:
        \\    vec3 cpin - Custom Point Input
        \\    float cdin - Custom Distance Input
        \\    float cdout - Custom Distance Output
        ,
    },
    .{
        .drawFn = util.prop.drawCodeProperty,
        .offset = @offsetOf(Data, "exit_function"),
        .name = "Distance Code",
        .prop_len = Data.max_func_len,
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    util.setBuffer(data.enter_function[0..], "cpout = cpin;");
    util.setBuffer(data.exit_function[0..], "cdout = cdin;");

    buffer.* = util.std.mem.asBytes(data);
}
