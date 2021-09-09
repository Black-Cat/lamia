const Scene = @import("scene/scene.zig").Scene;
const FileWatcher = @import("scene/file_watcher.zig").FileWatcher;

pub var main_scene: Scene = undefined;

pub var file_watcher: FileWatcher = undefined;
