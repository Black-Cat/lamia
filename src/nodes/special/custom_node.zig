usingnamespace @import("../node_utils.zig");

pub const CustomNode: NodeType = .{
    .name = "Custom Node",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
};

const Data = nsdf.CustomNode.Data;

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

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const next_point: []const u8 = std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "cpin = {s}; {{ {s} }} vec3 {s} = cpout;";
    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        ctxt.cur_point_name,
        @ptrCast([*c]const u8, data.enter_function.ptr),
        next_point,
    }) catch unreachable;

    ctxt.pushPointName(next_point);

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, 0);

    return res;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    ctxt.popPointName();

    const format: []const u8 = "cdin = d{d}; cpin = {s}; {{ {s} }} float d{d} = cdout;";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_index == ctxt.last_value_set_index) {
        res = std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;
    } else {
        res = std.fmt.allocPrint(ctxt.allocator, format, .{
            ctxt.last_value_set_index,
            ctxt.cur_point_name,
            @ptrCast([*c]const u8, data.exit_function.ptr),
            data.enter_index,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
