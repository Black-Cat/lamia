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

    const DateTime = struct {
        year: u16 = 0,
        month: u4 = 0,
        day: u5 = 0,
        hours: u5 = 0,
        minutes: u6 = 0,
        seconds: u6 = 0,
        time_zone: i5 = 0,

        fn parse(str: []const u8) !DateTime {
            var dt: DateTime = .{};
            dt.year = try std.fmt.parseInt(@TypeOf(dt.year), str[0..4], 10);
            dt.month = try std.fmt.parseInt(@TypeOf(dt.month), str[5..7], 10);
            dt.day = try std.fmt.parseInt(@TypeOf(dt.day), str[8..10], 10);
            if (str.len <= 10 or str[10] != 'T')
                return dt;

            dt.hours = try std.fmt.parseInt(@TypeOf(dt.hours), str[11..13], 10);
            dt.minutes = try std.fmt.parseInt(@TypeOf(dt.minutes), str[14..16], 10);
            dt.seconds = try std.fmt.parseInt(@TypeOf(dt.seconds), str[17..19], 10);
            if (str.len <= 20)
                return dt;

            dt.time_zone = try std.fmt.parseInt(@TypeOf(dt.time_zone), str[19..22], 10);
            return dt;
        }
    };

    const FileName = struct {
        name: []const u8,
        time_stamp: DateTime,
        author: []const u8,
        organization: []const u8,
        preprocessor_version: []const u8,
        originating_system: []const u8,
        authorization: []const u8,
    };

    allocator: std.mem.Allocator,
    iso: [2]u16,
    file_description: FileDescription,
    file_name: FileName,

    fn destroy(self: *StepData) void {
        self.allocator.free(self.file_description.description);

        self.allocator.free(self.file_name.name);
        self.allocator.free(self.file_name.author);
        self.allocator.free(self.file_name.organization);
        self.allocator.free(self.file_name.preprocessor_version);
        self.allocator.free(self.file_name.originating_system);
        self.allocator.free(self.file_name.authorization);
    }
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

fn parseFileName(step_data: *StepData, content: []const u8) !void {
    var it = std.mem.splitScalar(u8, content, '\'');

    _ = it.next() orelse return error.OutOfBounds;
    var name: []const u8 = it.next() orelse return error.OutOfBounds;
    var unescaped_name = std.ArrayList(u8).init(step_data.allocator);
    var ind: usize = 0;
    while (ind < name.len) {
        if (name[ind] == '\\') {
            ind += 1;
            if (ind >= name.len)
                break;
        }

        try unescaped_name.append(name[ind]);
        ind += 1;
    }
    step_data.file_name.name = try unescaped_name.toOwnedSlice();

    _ = it.next() orelse return error.OutOfBounds;
    var time_stamp: []const u8 = it.next() orelse return error.OutOfBounds;
    step_data.file_name.time_stamp = try StepData.DateTime.parse(time_stamp);

    var fields: [5]*[]const u8 = [_]*[]const u8{
        &step_data.file_name.author,
        &step_data.file_name.organization,
        &step_data.file_name.preprocessor_version,
        &step_data.file_name.originating_system,
        &step_data.file_name.authorization,
    };

    for (fields) |f| {
        _ = it.next() orelse return error.OutOfBounds;
        var field_val: []const u8 = it.next() orelse return error.OutOfBounds;
        f.* = try step_data.allocator.dupe(u8, field_val);
    }
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
            .FILE_NAME => try parseFileName(step_data, hl[command_end_pos..]),
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
    defer step_data.destroy();

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
