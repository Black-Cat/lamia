usingnamespace @import("../node_utils.zig");

pub const DisplacementNoise: NodeType = .{
    .name = "Displacement Noise",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
};

const Data = struct {
    power: f32,
    scale: f32,

    enter_index: usize,
    enter_stack: usize,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "power"),
        .name = "Power",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "scale"),
        .name = "Scale",
    },
};

const function_defenition: []const u8 =
    // Simplex 2D noise
    \\vec3 opDisplaceNoise_permute(vec3 x){
    \\  return mod(((x*34.)+1.)*x, 289.);
    \\}
    \\float opDisplaceNoise_snoise(vec2 v){
    \\  const vec4 c = vec4(.211324865405187, .366025403784439, -.577350269189626, .024390243902439);
    \\  vec2 i = floor(v + dot(v, c.yy));
    \\  vec2 x0 = v - i + dot(i, c.xx);
    \\  vec2 i1 = (x0.x > x0.y) ? vec2(1.,0.) : vec2(0.,1.);
    \\  vec4 x12 = x0.xyxy + c.xxzz;
    \\  x12.xy -= i1;
    \\  i = mod(i, 289.);
    \\  vec3 p = opDisplaceNoise_permute(opDisplaceNoise_permute(i.y + vec3(0., i1.y, 1.)) + i.x + vec3(0.,i1.x, 1.));
    \\  vec3 m = max(.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),dot(x12.zw,x12.zw)), 0.);
    \\  m *= m;
    \\  m *= m;
    \\  vec3 x = 2. * fract(p * c.www) - 1.;
    \\  vec3 h = abs(x) - .5;
    \\  vec3 ox = floor(x + .5);
    \\  vec3 a0 = x - ox;
    \\  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
    \\  vec3 g;
    \\  g.x = a0.x * x0.x + h.x * x0.y;
    \\  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    \\  return 130. * dot(m, g);
    \\}
    \\vec3 opDisplaceNoise(vec3 p, float power, float scale){
    \\  p.y += power * opDisplaceNoise_snoise(p.xz * scale);
    \\  return p;
    \\}
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.power = 0.1;
    data.scale = 1.0;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(Data), buffer.ptr));

    const next_point: []const u8 = std.fmt.allocPrint(ctxt.allocator, "p{d}", .{iter}) catch unreachable;

    const format: []const u8 = "vec3 {s} = opDisplaceNoise({s}, {d:.5}, {d:.5});";
    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{ next_point, ctxt.cur_point_name, data.power, data.scale }) catch unreachable;

    ctxt.pushPointName(next_point);

    return res;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    ctxt.popPointName();
    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}
