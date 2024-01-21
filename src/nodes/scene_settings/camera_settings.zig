const util = @import("../node_utils.zig");

const Global = @import("../../global.zig");

const NodeProperty = @import("../node_property.zig").NodeProperty;

pub const CameraSettings: util.NodeType = .{
    .name = "Camera Settings",
    .function_definition = "",

    .properties = properties[0..],

    .init_data_fn = initData,
    .deinit_fn = util.defaultDeinit(Data),

    .enter_command_fn = enterCommand,

    .has_on_load = true,
    .on_load_fn = updateGlobalCameras,
};

pub const ProjectionType = enum(u32) {
    perspective,
    orthographic,
};

pub const Data = struct {
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
        .drawFn = drawProjectionProperty,
        .offset = @offsetOf(Data, "projection"),
        .name = "Projection",
        .enum_combo_names = Data.projection_names[0..],
    },
};

pub fn drawProjectionProperty(self: *const NodeProperty, data: *[]u8) bool {
    const changed: bool = util.prop.drawEnumProperty(self, data);
    if (changed) {
        var data_ptr: [*c]u32 = @ptrCast(@alignCast(&data.*[self.offset]));
        const current_index: usize = data_ptr[0];
        const projection: ProjectionType = @enumFromInt(current_index);
        for (Global.cameras.items) |c|
            c.setProjection(projection);
    }
    return changed;
}

pub fn updateGlobalCameras(buffer: *[]u8) void {
    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

    for (Global.cameras.items) |c|
        c.setProjection(data.projection);
}

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

    const data: *Data = @ptrCast(@alignCast(buffer.ptr));

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
        @intFromEnum(data.projection),
    }) catch unreachable;
}
