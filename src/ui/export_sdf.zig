const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;
const Global = @import("../global.zig");

const file_path_len: usize = 256;
var selected_file_path: [file_path_len]u8 = [_]u8{0} ** file_path_len;

fn exportSdf() void {
    const path: []const u8 = std.mem.sliceTo(&selected_file_path, 0);
    Global.main_scene.saveNyanSdf(path) catch unreachable;
}

pub fn drawExportSdfDialog() void {
    var close_modal: bool = true;
    if (nc.igBeginPopupModal("Export to NyanSDF", &close_modal, nc.ImGuiWindowFlags_None)) {
        if (nc.igInputText("Path", @ptrCast(&selected_file_path), file_path_len, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
            exportSdf();
            nc.igCloseCurrentPopup();
        }

        if (nc.igButton("Export", .{ .x = 0, .y = 0 })) {
            exportSdf();
            nc.igCloseCurrentPopup();
        }

        nc.igSameLine(200.0, 2.0);
        if (nc.igButton("Cancel", .{ .x = 0, .y = 0 }))
            nc.igCloseCurrentPopup();

        nc.igEndPopup();
    }
}
