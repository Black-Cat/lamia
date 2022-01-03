const util = @import("../node_utils.zig");

pub const CustomMaterial: util.NodeType = .{
    .name = util.nsdf.CustomMaterial.info.name,
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
};

const Data = util.nsdf.CustomMaterial.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawHelpProperty,
        .offset = undefined,
        .name = 
        \\Values:
        \\    in vec3 l - Light Direction
        \\    in vec3 n - Normal
        \\    in vec3 v - Ray Position
        \\    out vec3 res - Result Color
        ,
    },
    .{
        .drawFn = util.prop.drawCodeProperty,
        .offset = @offsetOf(Data, "material_function"),
        .name = "Code",
        .prop_len = Data.max_func_len,
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    util.setBuffer(data.material_function[0..], "float nl = dot(n, l);\nres = vec3(max(0., nl));\n");

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    return util.std.fmt.allocPrint(ctxt.allocator, "{s}", .{@ptrCast([*c]const u8, &data.material_function)}) catch unreachable;
}
