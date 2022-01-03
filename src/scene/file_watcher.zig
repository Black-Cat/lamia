const std = @import("std");
const nyan = @import("nyancore");
const Allocator = std.mem.Allocator;

const Scene = @import("scene.zig").Scene;

const FileRecord = struct {
    scene: Scene,
    ref_count: u32,
    modified_time: i128,
};

const FileMap = std.StringArrayHashMap(FileRecord);
const PathList = std.ArrayList([]const u8);

pub const FileWatcher = struct {
    system: nyan.System,
    allocator: Allocator,
    map: FileMap,
    toRemove: PathList,
    timer: f64,

    pub fn init(self: *FileWatcher, allocator: Allocator) void {
        self.system = .{
            .name = "File Watcher",
            .init = systemInit,
            .deinit = systemDeinit,
            .update = systemUpdate,
        };
        self.allocator = allocator;
        self.map = FileMap.init(self.allocator);
        self.toRemove = PathList.init(self.allocator);
        self.timer = 0.0;
    }

    pub fn deinit(self: *FileWatcher) void {
        var it = self.map.iterator();
        while (it.next()) |entry|
            entry.value_ptr.scene.deinit();

        self.map.deinit();
        self.toRemove.deinit();
    }

    // Returns true if adding file was a success
    pub fn addExternFile(self: *FileWatcher, path: []const u8) bool {
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.openFile(path, .{}) catch return false;
        const stat: std.fs.File.Stat = file.stat() catch return false;
        file.close();

        var record: FileRecord = .{
            .scene = undefined,
            .ref_count = 0,
            .modified_time = stat.mtime,
        };
        record.scene.init();
        record.scene.load(path) catch return false;
        self.map.put(path, record) catch unreachable;
        return true;
    }

    fn systemInit(system: *nyan.System, app: *nyan.Application) void {
        _ = system;
        _ = app;
    }

    fn systemDeinit(system: *nyan.System) void {
        _ = system;
    }

    fn systemUpdate(system: *nyan.System, elapsed_time: f64) void {
        const self: *FileWatcher = @fieldParentPtr(FileWatcher, "system", system);

        self.timer += elapsed_time;
        if (self.timer < 5.0)
            return;
        self.timer = 0.0;

        var it = self.map.iterator();
        while (it.next()) |entry| {
            reloadIfNeeded(entry.key_ptr, entry.value_ptr);
            if (entry.value_ptr.ref_count == 0)
                self.toRemove.append(entry.key_ptr.*) catch unreachable;
        }

        for (self.toRemove.items) |r| {
            var record: FileRecord = self.map.fetchSwapRemove(r).?.value;
            record.scene.deinit();
        }

        self.toRemove.clearRetainingCapacity();
    }

    fn reloadIfNeeded(path: *[]const u8, record: *FileRecord) void {
        // Don't fail if file is bad, just keep last version
        const cwd: std.fs.Dir = std.fs.cwd();
        const file: std.fs.File = cwd.openFile(path.*, .{}) catch return;
        const stat: std.fs.File.Stat = file.stat() catch return;
        file.close();

        if (record.modified_time < stat.mtime) {
            record.modified_time = stat.mtime;
            record.scene.load(path.*) catch return;
        }
    }
};
