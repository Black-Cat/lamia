usingnamespace @import("../node_utils.zig");

pub const BoundingBox: NodeType = .{
    .name = "Bounding Box",
    .function_defenition = function_defenition,

    .properties = properties[0..],

    .init_data_fn = initData,
    .enterCommandFn = enterCommand,
    .exitCommandFn = exitCommand,
    .appendMatCheckFn = appendMatCheckSurface,
};

const Data = struct {
    size: [3]f32,
    extent: f32,

    enter_index: usize,
    enter_stack: usize,
    mat: usize,
};

const properties = [_]NodeProperty{
    .{
        .drawFn = drawFloat3Property,
        .offset = @byteOffsetOf(Data, "size"),
        .name = "Size",
    },
    .{
        .drawFn = drawFloatProperty,
        .offset = @byteOffsetOf(Data, "extent"),
        .name = "Extent",
    },
    .{
        .drawFn = drawMaterialProperty,
        .offset = @byteOffsetOf(Data, "mat"),
        .name = "Material",
    },
};

const function_defenition: []const u8 =
    \\float sdBoundingBox(vec3 p, vec3 b, float e){
    \\  p = abs(p) - b - e;
    \\  vec3 q = abs(p + e) - e;
    \\  return min(min(
    \\    length(max(vec3(p.x,q.y,q.z),0.))+min(max(p.x,max(q.y,q.z)),0.),
    \\    length(max(vec3(q.x,p.y,q.z),0.))+min(max(q.x,max(p.y,q.z)),0.)),
    \\    length(max(vec3(q.x,q.y,p.z),0.))+min(max(q.x,max(q.y,p.z)),0.));
    \\}
    \\
;

fn initData(buffer: *[]u8) void {
    const data: *Data = nyan.app.allocator.create(Data) catch unreachable;

    data.size = [_]f32{ 1.0, 1.0, 1.0 };
    data.extent = 0.1;
    data.mat = 0;

    buffer.* = std.mem.asBytes(data);
}

fn enterCommand(ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    data.enter_index = iter;
    data.enter_stack = ctxt.value_indexes.items.len;
    ctxt.pushStackInfo(iter, @intCast(i32, data.mat + mat_offset));

    return std.fmt.allocPrint(ctxt.allocator, "", .{}) catch unreachable;
}

fn exitCommand(ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "float d{d} = sdBoundingBox({s}, vec3({d:.5},{d:.5},{d:.5}),{d:.5});";

    const res: []const u8 = std.fmt.allocPrint(ctxt.allocator, format, .{
        data.enter_index,
        ctxt.cur_point_name,
        data.size[0],
        data.size[1],
        data.size[2],
        data.extent,
    }) catch unreachable;

    ctxt.dropPreviousValueIndexes(data.enter_stack);

    return res;
}

pub fn appendMatCheckSurface(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, allocator: *std.mem.Allocator) []const u8 {
    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 = "{s}if(d{d}<MAP_EPS)return matToColor({d}.,l,n,v);";
    return std.fmt.allocPrint(allocator, format, .{
        exit_command,
        data.enter_index,
        data.mat + mat_offset,
    }) catch unreachable;
}
