pub const std = @import("std");
pub const nyan = @import("nyancore");
pub const nm = nyan.Math;
pub const nsdf = nyan.Sdf;

pub const NodeType = @import("node_type.zig").NodeType;
pub const IterationContext = nsdf.IterationContext;

pub const viewport_gizmos = @import("../ui/widgets/viewport_gizmos.zig");
pub const GizmoStorage = viewport_gizmos.GizmoStorage;
pub const SizeGizmo = viewport_gizmos.SizeGizmo;
pub const TranslationGizmo = viewport_gizmos.TranslationGizmo;
pub const RotationGizmo = viewport_gizmos.RotationGizmo;

pub const prop = @import("node_property.zig");
pub const NodeProperty = prop.NodeProperty;

pub fn setBuffer(buffer: []u8, data: []const u8) void {
    @memcpy(buffer[0 .. data.len + 1], data.ptr);
}

pub fn defaultDeinit(comptime DT: type) fn (buffer: *[]u8) void {
    return struct {
        fn f(buffer: *[]u8) void {
            const data: *DT = @ptrCast(@alignCast(buffer.ptr));
            nyan.app.allocator.destroy(data);
        }
    }.f;
}
