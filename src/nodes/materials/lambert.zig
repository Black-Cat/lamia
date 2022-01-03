const util = @import("../node_utils.zig");

pub const Lambert: util.NodeType = .{
    .name = util.nsdf.Lambert.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,

    .enterCommandFn = enterCommand,
};

const function_defenition: []const u8 =
    \\vec3 matLambert(vec3 l, vec3 n, vec3 col){
    \\  float nl = dot(n, l);
    \\  return max(0.,nl) * col;
    \\}
    \\
;

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

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "res = matLambert(l,n,vec3({d:.5},{d:.5},{d:.5}));";

    return util.std.fmt.allocPrint(ctxt.allocator, format, .{ data.color[0], data.color[1], data.color[2] }) catch unreachable;
}
