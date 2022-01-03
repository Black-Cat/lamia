const util = @import("../node_utils.zig");

pub const CameraSettings: util.NodeType = .{
    .name = "Camera Settings",
    .function_defenition = "",

    .properties = properties[0..],

    .init_data_fn = initData,

    .enterCommandFn = enterCommand,
};

pub const Data = struct {
    const ProjectionType = enum(u32) {
        perspective,
        orthographic,
    };
    const projection_names: [2][]const u8 = [_][]const u8{
        "Perspective",
        "Orthographic",
    };

    near: f32,
    far: f32,
    fov: f32,
    steps: u32,
    projection: ProjectionType,
};

const properties = [_]util.NodeProperty{
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "near"),
        .name = "Near",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "far"),
        .name = "Far",
    },
    .{
        .drawFn = util.prop.drawFloatProperty,
        .offset = @offsetOf(Data, "fov"),
        .name = "FOV",
    },
    .{
        .drawFn = util.prop.drawU32Property,
        .offset = @offsetOf(Data, "steps"),
        .name = "Max Steps",
    },
    .{
        .drawFn = util.prop.drawEnumProperty,
        .offset = @offsetOf(Data, "projection"),
        .name = "Projection",
        .enum_combo_names = Data.projection_names[0..],
    },
};

fn initData(buffer: *[]u8) void {
    const data: *Data = util.nyan.app.allocator.create(Data) catch unreachable;

    data.near = 0.1;
    data.far = 100.0;
    data.fov = 60.0;
    data.steps = 128;
    data.projection = .perspective;

    buffer.* = util.std.mem.asBytes(data);
}

fn enterCommand(ctxt: *util.IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 {
    _ = iter;
    _ = mat_offset;

    const data: *Data = @ptrCast(*Data, @alignCast(@alignOf(*Data), buffer.ptr));

    const format: []const u8 =
        \\#define CAMERA_NEAR {d:.5}
        \\#define CAMERA_FAR {d:.5}
        \\#define CAMERA_FOV {d:.5}
        \\#define CAMERA_STEPS {d}
        \\#define CAMERA_PROJECTION {d}
        \\
    ;

    return util.std.fmt.allocPrint(ctxt.allocator, format, .{
        data.near,
        data.far,
        util.std.math.tan(data.fov / 2.0 * (util.std.math.pi / 180.0)),
        data.steps,
        @enumToInt(data.projection),
    }) catch unreachable;
}
