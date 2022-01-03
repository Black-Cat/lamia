const util = @import("../node_utils.zig");

pub const CustomNode: util.NodeType = .{
    .name = util.nsdf.CustomNode.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
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

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const next_point: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "cpin = {s}; {{ {s} }} vec3 {s} = cpout;";
    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
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

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    ctxt.popPointName();

    const format: []const u8 = "cdin = d{d}; cpin = {s}; {{ {s} }} float d{d} = cdout;";
    const broken_stack: []const u8 = "float d{d} = 1e10;";

    var res: []const u8 = undefined;
    if (data.enter_index == ctxt.last_value_set_index) {
        res = util.std.fmt.allocPrint(ctxt.allocator, broken_stack, .{data.enter_index}) catch unreachable;
    } else {
        res = util.std.fmt.allocPrint(ctxt.allocator, format, .{
            ctxt.last_value_set_index,
            ctxt.cur_point_name,
            @ptrCast([*c]const u8, data.exit_function.ptr),
            data.enter_index,
        }) catch unreachable;
    }

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}
