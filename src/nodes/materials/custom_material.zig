usingnamespace @import("../node_utils.zig");

pub const CustomMaterial: NodeType = .{
    .name = "Custom Material",
    .function_defenition = "",

    .init_data_fn = initData,
};

const Data = struct {
    material_function: [1024]u8,
};

fn initData(buffer: **c_void, buffer_size: *usize) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    setBuffer(data.material_function, "float nl = dot(n, l);\nres = vec3(max(0., nl));\n");

    buffer.* = @ptrCast(*c_void, data);
    buffer_size.* = @sizeOf(Data);
}
