const std = @import("std");
const nyan = @import("nyancore");
const nm = nyan.Math;
const nsdf = nyan.Sdf;
const NodeProperty = @import("node_property.zig").NodeProperty;
const GizmoStorage = @import("../ui/widgets/viewport_gizmos.zig").GizmoStorage;

fn appendNoGizmos(buffer: *[]u8, gizmo_storage: *GizmoStorage) void {
    _ = buffer;
    _ = gizmo_storage;
}

fn dontModifyGizmos(buffer: *[]u8, points: []nm.vec4) void {
    _ = buffer;
    _ = points;
}

pub const NodeType = struct {
    name: []const u8,
    function_definition: []const u8,

    properties: []const NodeProperty,

    init_data_fn: fn (buffer: *[]u8) void,

    has_edit_callback: bool = false,
    edit_callback: fn (buffer: *[]u8) void = undefined,

    has_deinit: bool = false,
    deinit_fn: fn (buffer: *[]u8) void = undefined,

    has_on_load: bool = false,
    on_load_fn: fn (buffer: *[]u8) void = undefined,

    external: bool = false, // Used only for File Scene Node

    enter_command_fn: nsdf.EnterCommandFn = undefined,
    exit_command_fn: nsdf.ExitCommandFn = undefined,
    append_mat_check_fn: nsdf.AppendMatCheckFn = nsdf.appendNoMatCheck,

    appendGizmosFn: fn (buffer: *[]u8, gizmo_storage: *GizmoStorage) void = appendNoGizmos,

    modifyGizmoPointsFn: fn (buffer: *[]u8, points: []nm.vec4) void = dontModifyGizmos,

    maxChildCount: usize = 1,
};
