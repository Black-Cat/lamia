usingnamespace @import("../node_utils.zig");

pub const OrenNayar: NodeType = .{
    .name = nsdf.OrenNayar.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
};

const Data = nsdf.OrenNayar.Data;

const properties = [_]NodeProperty{
    .{
        .drawFn = drawColor3Property,
        .offset = @byteOffsetOf(Data, "color"),
        .name = "Color",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "roughness"),
        .name = "Roughness",
    },
};

const function_defenition: []const u8 =
    \\vec3 matOrenNayar(vec3 l, vec3 n, vec3 v, vec3 col, float r){
    \\  float r2 = r*r;
    \\  float a = 1.-.5*(r2/(r2+.57));
    \\  float b = .45*(r2/(r2+.09));
    \\
    \\  float nl = dot(n,l);
    \\  float nv = dot(n,v);
    \\
    \\  float ga=dot(v-n*nv,n-n*nl);
    \\  return col * max(0.,nl) * (a+b*max(0.,ga)*sqrt((1.-nv*nv)*(1.-nl*nl))/max(nl,nv));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.color = [3]f32{ 0.8, 0.8, 0.8 };
    data.roughness = 1.0;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "res = matOrenNayar(l,n,v,vec3({d:.5},{d:.5},{d:.5}),{d:.5});";

    return std.fmt.allocPrint(ctxt.allocator, format, .{
        data.color[0],
        data.color[1],
        data.color[2],
        data.roughness,
    }) catch unreachable;
}
