const std = @import("std");

const Camera = @import("scene/camera.zig").Camera;
const Scene = @import("scene/scene.zig").Scene;
const FileWatcher = @import("scene/file_watcher.zig").FileWatcher;

pub var main_scene: Scene = undefined;

pub var file_watcher: FileWatcher = undefined;

pub var cameras: std.ArrayList(*Camera) = undefined;

pub fn init_cameras(allocator: std.mem.Allocator) void {
    cameras = std.ArrayList(*Camera).init(allocator);
}

pub fn deinit_cameras() void {
    cameras.deinit();
}
