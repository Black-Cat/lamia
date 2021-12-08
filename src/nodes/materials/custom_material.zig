usingnamespace @import("../node_utils.zig");

pub const CustomMaterial: NodeType = .{
    .name = "Custom Material",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
};

const Data = nsdf.CustomMaterial.Data;

const properties = [_]NodeProperty{
    .{
        .drawFn = drawHelpProperty,
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
        .drawFn = drawCodeProperty,
        .offset = @byteOffsetOf(Data, "material_function"),
        .name = "Code",
        .prop_len = Data.max_func_len,
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    setBuffer(data.material_function[0..], "float nl = dot(n, l);\nres = vec3(max(0., nl));\n");

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    return std.fmt.allocPrint(ctxt.allocator, "{s}", .{@ptrCast([*c]const u8, &data.material_function)}) catch unreachable;
}
