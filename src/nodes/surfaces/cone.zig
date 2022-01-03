const util = @import("../node_utils.zig");

pub const Cone: util.NodeType = .{
    .name = util.nsdf.Cone.info.name,
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
};

const Data = util.nsdf.Cone.Data;

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "angle"),
        .name = "Angle",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "height"),
        .name = "Height",
    },
    .{
        .drawFn = util.prop.drawMaterialProperty,
        .offset = @offsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdCone(vec3 p, vec2 q){
    \\  vec2 w = vec2(length(p.xz), p.y);
    \\  vec2 a = w - q * clamp(dot(w,q)/dot(q,q), 0., 1.);
    \\  vec2 b = w - q * vec2(clamp(w.x/q.x, 0., 1.), 1.);
    \\  float k = sign(q.y);
    \\  float d = min(dot(a,a),dot(b,b));
    \\  float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
    \\  return sqrt(d) * sign(s);
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.angle = 0.5;
    data.height = 1.0;
    data.mat = 0;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return util.std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *util.IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    _ = iter;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdCone({s}, vec2({d:.5},{d:.5}));";

    const qx: f32 = data.height * (@sin(data.angle) / @cos(data.angle));
    const qy: f32 = data.height * -1.0;

    const res: []const u8 = util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        qx,
        qy,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

pub fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: util.std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return util.std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}
