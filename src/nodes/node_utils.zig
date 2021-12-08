pub const std = @import("std");
pub const nyan = @import("nyancore");
pub const nm = nyan.Math;
pub const nsdf = nyan.Sdf;

pub const NodeType = @import("node_type.zig").NodeType;
pub const IterationContext = @import("node_type.zig").IterationContext;

pub const viewport_gizmos = @import("../ui/widgets/viewport_gizmos.zig");
pub const GizmoStorage = viewport_gizmos.GizmoStorage;
pub const SizeGizmo = viewport_gizmos.SizeGizmo;
pub const TranslationGizmo = viewport_gizmos.TranslationGizmo;
pub const RotationGizmo = viewport_gizmos.RotationGizmo;

pub usingnamespace @import("node_property.zig");

pub fn setBuffer(buffer: []u8, data: []const u8) void {
    @memcpy(@ptrCast([*]u8, &buffer[0]), data.ptr, data.len + 1);
}
