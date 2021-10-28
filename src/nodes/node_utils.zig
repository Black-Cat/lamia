pub const std = @import("std");
pub const nyan = @import("nyancore");

pub const NodeType = @import("node_type.zig").NodeType;
pub const IterationContext = @import("node_type.zig").IterationContext;
pub usingnamespace @import("node_property.zig");

pub fn setBuffer(buffer: []u8, data: []const u8) void {
    @memcpy(@ptrCast([*]u8, &buffer[0]), data.ptr, data.len + 1);
}
