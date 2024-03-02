const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;

const file_path_len: usize = 256;
var selected_file_path: [file_path_len]u8 = [_]u8{0} ** file_path_len;

pub const popup_title: []const u8 = "Import STEP File";

const StepParseError = error{
    WrongSignature,
};

pub const StepData = struct {
    allocator: std.mem.Allocator,
    iso: [2]u16,
};

fn readFileSignature(step_data: *StepData, reader: anytype) !void {
    var sig: std.ArrayList(u8) = std.ArrayList(u8).init(step_data.allocator);
    defer sig.deinit();

    try reader.streamUntilDelimiter(sig.writer(), '-', 5);

    if (sig.items.len != 3 or sig.items[0] != 'I' or sig.items[1] != 'S' or sig.items[2] != 'O')
        return StepParseError.WrongSignature;
    sig.clearRetainingCapacity();

    try reader.streamUntilDelimiter(sig.writer(), '-', 10);
    step_data.iso[0] = try std.fmt.parseInt(@TypeOf(step_data.iso[0]), sig.items, 10);
    sig.clearRetainingCapacity();

    try reader.streamUntilDelimiter(sig.writer(), ';', 10);
    step_data.iso[1] = try std.fmt.parseInt(@TypeOf(step_data.iso[1]), sig.items, 10);

    try reader.skipUntilDelimiterOrEof('\n');
}

pub fn importStepFile(path: []const u8) !void {
    const cwd: std.fs.Dir = std.fs.cwd();
    const file: std.fs.File = try cwd.openFile(path, .{ .mode = .read_only });
    defer file.close();

    var step_data: StepData = undefined;
    step_data.allocator = nyan.app.allocator;

    const reader = file.reader();
    try readFileSignature(&step_data, reader);
}

pub fn drawImportStepDialog() void {
    var close_modal: bool = true;
    if (nc.igBeginPopupModal(@ptrCast(popup_title), &close_modal, nc.ImGuiWindowFlags_None)) {
        if (nc.igInputText("Path", @ptrCast(&selected_file_path), file_path_len, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null)) {
            importStepFile(std.mem.sliceTo(&selected_file_path, 0)) catch |er| debugError(er);
            nc.igCloseCurrentPopup();
        }

        if (nc.igButton("Import", .{ .x = 0, .y = 0 })) {
            importStepFile(std.mem.sliceTo(&selected_file_path, 0)) catch |er| debugError(er);
            nc.igCloseCurrentPopup();
        }

        nc.igSameLine(200.0, 2.0);
        if (nc.igButton("Cancel", .{ .x = 0, .y = 0 }))
            nc.igCloseCurrentPopup();

        nc.igEndPopup();
    }
}

fn debugError(er: anytype) void {
    std.debug.print("{}\n", .{er});
}
