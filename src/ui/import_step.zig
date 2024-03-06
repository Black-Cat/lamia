const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;

const file_path_len: usize = 256;
var selected_file_path: [file_path_len]u8 = [_]u8{0} ** file_path_len;

pub const popup_title: []const u8 = "Import STEP File";

const StepParseError = error{
    WrongSignature,
};

const StepHeaderCommand = enum {
    FILE_DESCRIPTION,
    FILE_NAME,
    FILE_SCHEMA,
};

pub const StepData = struct {
    const FileDescription = struct {
        description: []const u8,
        implementation_level: [2]u3,
    };

    allocator: std.mem.Allocator,
    iso: [2]u16,
    file_description: FileDescription,
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

fn parseFileDescription(step_data: *StepData, content: []const u8) !void {
    const desc_start: usize = (std.mem.indexOfScalarPos(u8, content, 0, '\'') orelse return error.OutOfBounds) + 1;
    const desc_end: usize = (std.mem.indexOfScalarPos(u8, content, desc_start, '\'') orelse return error.OutOfBounds);

    step_data.file_description.description = try step_data.allocator.dupe(u8, content[desc_start..desc_end]);

    const first_imp_pos: usize = (std.mem.indexOfScalarPos(u8, content, desc_end + 2, '\'') orelse return error.OutOfBounds) + 1;
    step_data.file_description.implementation_level[0] = @intCast(content[first_imp_pos] - '0');
    step_data.file_description.implementation_level[1] = @intCast(content[first_imp_pos + 2] - '0');
}

fn parseHeader(step_data: *StepData, reader: anytype) !void {
    var line = std.ArrayList(u8).init(step_data.allocator);
    defer line.deinit();

    while (true) {
        reader.streamUntilDelimiter(line.writer(), '\n', null) catch return;
        if (line.items.len > 0 and line.getLast() == '\r')
            _ = line.pop();

        if (std.mem.eql(u8, line.items, "HEADER;"))
            break;
        line.clearRetainingCapacity();
    }
    line.clearRetainingCapacity();

    var header_lines = std.ArrayList([]u8).init(step_data.allocator);
    defer header_lines.deinit();
    defer {
        for (header_lines.items) |hl|
            step_data.allocator.free(hl);
    }

    while (true) {
        reader.streamUntilDelimiter(line.writer(), '\n', null) catch return;
        if (line.items.len > 0 and line.getLast() == '\r')
            _ = line.pop();

        if (std.mem.eql(u8, line.items, "ENDSEC;"))
            break;

        if (line.items.len == 0)
            continue;

        header_lines.append(step_data.allocator.dupe(u8, line.items) catch unreachable) catch unreachable;
        line.clearRetainingCapacity();
    }

    for (header_lines.items) |hl| {
        const command_end_pos: usize = std.mem.indexOfScalar(u8, hl, '(') orelse continue;
        const command: StepHeaderCommand = std.meta.stringToEnum(StepHeaderCommand, hl[0..command_end_pos]) orelse continue;
        switch (command) {
            .FILE_DESCRIPTION => try parseFileDescription(step_data, hl[command_end_pos..]),
            .FILE_NAME => {},
            .FILE_SCHEMA => {},
        }
    }
}

pub fn importStepFile(path: []const u8) !void {
    const cwd: std.fs.Dir = std.fs.cwd();
    const file: std.fs.File = try cwd.openFile(path, .{ .mode = .read_only });
    defer file.close();

    var step_data: StepData = undefined;
    step_data.allocator = nyan.app.allocator;

    const reader = file.reader();
    try readFileSignature(&step_data, reader);
    try parseHeader(&step_data, reader);
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
