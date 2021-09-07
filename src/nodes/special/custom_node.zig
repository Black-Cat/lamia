usingnamespace @import("../node_utils.zig");

pub const CustomNode: NodeType = .{
    .name = "Custom Node",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = struct {
    const max_func_len: usize = 1024;
    enter_function: [max_func_len]u8,
    exit_function: [max_func_len]u8,

    enter_stack: i32,
    enter_index: i32,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawHelpProperty,
        .offset = undefined,
        .name = 
        \\Point variables:
        \\    vec3 cpin - Custom Point Input
        \\    vec3 cpout - Custom Point Output
        ,
    },
    .{
        .drawFn = drawCodeProperty,
        .offset = @byteOffsetOf(Data, "enter_function"),
        .name = "Point Code",
        .prop_len = Data.max_func_len,
    },
    .{
        .drawFn = drawHelpProperty,
        .offset = undefined,
        .name = 
        \\Distance variables:
        \\    vec3 cpin - Custom Point Input
        \\    float cdin - Custom Distance Input
        \\    float cdout - Custom Distance Output
        ,
    },
    .{
        .drawFn = drawCodeProperty,
        .offset = @byteOffsetOf(Data, "exit_function"),
        .name = "Distance Code",
        .prop_len = Data.max_func_len,
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    setBuffer(data.enter_function[0..], "cpout = cpin;");
    setBuffer(data.exit_function[0..], "cdout = cdin;");

    buffer.* = std.mem.asBytes(data);
}
