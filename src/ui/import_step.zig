const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;

const Global = @import("../global.zig");

const Scene = @import("../scene/scene.zig").Scene;
const SceneNode = @import("../scene/scene_node.zig").SceneNode;

const UnionNodeType = @import("../nodes/combinators/union.zig").Union;

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

    const FileSchema = struct {
        schema: []const u8,
        version: ?[]const u32,
    };

    fn parseStringArg(arg: []const u8, allocator: std.mem.Allocator) []const u8 {
        // Search for utf-16/32 end marker
        var str: []const u8 = arg[1 .. arg.len - 1];
        if (std.mem.indexOf(u8, str, "\\X0\\") == null)
            return allocator.dupe(u8, str) catch unreachable;

        var decoded_str = std.ArrayList(u8).init(allocator);

        const UtfMarker = enum { X2, X4, X0 };
        var state: UtfMarker = .X0;
        var prev_was_marker: bool = true;

        var it = std.mem.splitScalar(u8, str, '\\');
        while (it.next()) |s| {
            const unicode_marker: ?UtfMarker = std.meta.stringToEnum(UtfMarker, s) orelse null;

            if (unicode_marker == null) {
                switch (state) {
                    .X0 => {
                        // Restore innocent \ in string
                        if (!prev_was_marker)
                            decoded_str.append('\\') catch unreachable;
                        decoded_str.appendSlice(s) catch unreachable;
                    },
                    .X2 => {
                        var byte_it_2 = std.mem.window(u8, s, 4, 4);
                        while (byte_it_2.next()) |bytes_hex| {
                            var bytes: [2]u8 = [_]u8{
                                std.fmt.parseInt(u8, bytes_hex[0..2], 16) catch unreachable,
                                std.fmt.parseInt(u8, bytes_hex[2..4], 16) catch unreachable,
                            };

                            if (bytes[0] == 0) {
                                // 2 byte utf-8 representation
                                var utf8: [2]u8 = [_]u8{
                                    0b1100_0000,
                                    0b1000_0000,
                                };
                                utf8[0] |= (bytes[0] & 0b0000_0111) << 2;
                                utf8[0] |= (bytes[1] & 0b1100_0000) >> 6;
                                utf8[1] |= bytes[1] & 0b0011_1111;

                                decoded_str.appendSlice(&utf8) catch unreachable;
                            } else {
                                // 3 byte utf-8 representation
                                var utf8: [3]u8 = [_]u8{
                                    0b1110_0000,
                                    0b1000_0000,
                                    0b1000_0000,
                                };

                                utf8[0] |= (bytes[0] & 0b1111_0000) >> 4;
                                utf8[1] |= (bytes[0] & 0b0000_1111) << 2;
                                utf8[1] |= (bytes[1] & 0b1100_0000) >> 6;
                                utf8[2] |= bytes[1] & 0b0011_1111;

                                decoded_str.appendSlice(&utf8) catch unreachable;
                            }
                        }
                    },
                    .X4 => {
                        var byte_it_4 = std.mem.window(u8, s, 8, 8);
                        while (byte_it_4.next()) |bytes_hex| {
                            var bytes: [4]u8 = [_]u8{
                                // Documentation says that utf-32 encoded by 4 bytes in STEP
                                // But utf-32 only uses 21 bits and can be represented by 3 bytes
                                0, //std.fmt.parseInt(u8, bytes_hex[0..2], 16) catch unreachable,
                                std.fmt.parseInt(u8, bytes_hex[2..4], 16) catch unreachable,
                                std.fmt.parseInt(u8, bytes_hex[4..6], 16) catch unreachable,
                                std.fmt.parseInt(u8, bytes_hex[6..8], 16) catch unreachable,
                            };

                            var utf8: [4]u8 = [_]u8{
                                0b1111_0000,
                                0b1000_0000,
                                0b1000_0000,
                                0b1000_0000,
                            };

                            utf8[0] |= (bytes[1] & 0b0001_1100) >> 2;
                            utf8[1] |= (bytes[1] & 0b0000_0011) << 4;
                            utf8[1] |= (bytes[2] & 0b1111_0000) >> 4;
                            utf8[2] |= (bytes[2] & 0b0000_1111) << 2;
                            utf8[2] |= (bytes[3] & 0b1100_0000) >> 6;
                            utf8[3] |= bytes[3] & 0b0011_1111;

                            decoded_str.appendSlice(&utf8) catch unreachable;
                        }
                    },
                }
            } else {
                state = unicode_marker.?;
            }

            prev_was_marker = unicode_marker != null;
        }

        return decoded_str.toOwnedSlice() catch unreachable;
    }

    fn parseOptionalStringArg(arg: []const u8, allocator: std.mem.Allocator) ?[]const u8 {
        if (std.mem.eql(u8, arg, "\'\'"))
            return null;
        return parseStringArg(arg, allocator);
    }

    fn parseRefArrayArg(arg: []const u8, allocator: std.mem.Allocator) std.ArrayList(usize) {
        var refs = std.ArrayList(usize).init(allocator);

        var it = std.mem.tokenizeScalar(u8, arg, ',');

        while (it.next()) |val| {
            refs.append(std.fmt.parseInt(usize, val[1..], 10) catch unreachable) catch unreachable;
        }

        return refs;
    }

    fn parseRef(arg: []const u8) usize {
        return std.fmt.parseInt(usize, arg[1..], 10) catch unreachable;
    }

    const StepEntityFields = enum {
        String,
        OptionalString,
        Reference,
        SetOfReferences,
    };

    const EntityFieldDescription = struct {
        name: []const u8,
        type: StepEntityFields,
    };

    const EntityDescription = struct {
        field_descriptions: []const EntityFieldDescription,
    };

    fn EntityStruct(comptime name: []const u8, comptime description: EntityDescription) type {
        _ = name; // Used to deduce typename
        var fields: [description.field_descriptions.len]std.builtin.Type.StructField = undefined;
        for (description.field_descriptions, &fields) |fd, *f|
            f.* = .{
                .name = fd.name,
                .type = switch (fd.type) {
                    .String => []const u8,
                    .OptionalString => ?[]const u8,
                    .Reference => usize,
                    .SetOfReferences => std.ArrayList(usize),
                },
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };

        const Data = @Type(.{
            .Struct = .{
                .layout = .Auto,
                .fields = fields[0..],
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = false,
            },
        });

        return struct {
            const Self = @This();

            allocator: std.mem.Allocator,
            d: Data,

            fn parseArgs(self: *Self, it: anytype) void {
                inline for (description.field_descriptions) |fd| {
                    @field(self.d, fd.name) = switch (fd.type) {
                        .String => parseStringArg(it.next() orelse unreachable, self.allocator),
                        .OptionalString => parseOptionalStringArg(it.next() orelse unreachable, self.allocator),
                        .Reference => parseRef(it.next() orelse unreachable),
                        .SetOfReferences => parseRefArrayArg(it.next() orelse unreachable, self.allocator),
                    };
                }
            }

            fn deinit(self: *Self) void {
                inline for (description.field_descriptions) |fd| {
                    switch (fd.type) {
                        .String => self.allocator.free(@field(self.d, fd.name)),
                        .OptionalString => if (@field(self.d, fd.name)) |f|
                            self.allocator.free(f),
                        .Reference => {},
                        .SetOfReferences => @field(self.d, fd.name).deinit(),
                    }
                }
            }
        };
    }

    const Product = EntityStruct("Product", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "id", .type = .String },
            .{ .name = "name", .type = .String },
            .{ .name = "description", .type = .String },
            .{ .name = "frame_of_reference", .type = .SetOfReferences },
        },
    });

    const ProductContext = EntityStruct("ProductContext", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "name", .type = .String },
            .{ .name = "application_context", .type = .Reference }, // Reference ot APPLICATION_CONTEXT
            .{ .name = "discipline_type", .type = .String },
        },
    });

    const ApplicationContext = EntityStruct("ApplicationContext", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "application", .type = .String },
        },
    });

    const ProductDefinition = EntityStruct("ProductDefinition", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "id", .type = .String },
            .{ .name = "description", .type = .OptionalString },
            .{ .name = "formation", .type = .Reference }, // Reference to PRODUCT_DEFINITION_FORMATION
            .{ .name = "frame_of_reference", .type = .Reference }, // Reference to PRODUCT_DEFINITION_CONTEXT
        },
    });

    const ProductDefinitionContext = EntityStruct("ProductDefinitionContext", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "name", .type = .String },
            .{ .name = "frame_of_reference", .type = .Reference }, // Reference to APPLICATION_CONTEXT
            .{ .name = "life_cycle_stage", .type = .String },
        },
    });

    const ProductDefinitionShape = EntityStruct("ProductDefinitionShape", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "name", .type = .String },
            .{ .name = "description", .type = .String },
            .{ .name = "definition", .type = .Reference }, // Reference to PRODUCT_DEFINITION
        },
    });

    const MechanicalDesignGeometricPresentationRepresentation = EntityStruct("MechanicalDesignGeometricPresentationRepresentation", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "name", .type = .String },
            .{ .name = "items", .type = .SetOfReferences }, // Reference to MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION_ITEMS
            .{ .name = "context_of_items", .type = .Reference }, // Reference to REPRESENTATION_CONTEXT
        },
    });

    const ShapeRepresentation = EntityStruct("ShapeRepresentation", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "name", .type = .String },
            .{ .name = "items", .type = .SetOfReferences }, // Reference to REPRESENTATION_ITEM
            .{ .name = "context_of_items", .type = .Reference }, // Reference to REPRESENTATION_CONTEXT
        },
    });

    const ItemDefinedTransformation = EntityStruct("ItemDefinedTransformation", .{
        .field_descriptions = &[_]EntityFieldDescription{
            .{ .name = "name", .type = .String },
            .{ .name = "description", .type = .String },
            .{ .name = "transform_item_1", .type = .Reference }, // Reference to REPRESENTATION_ITEM
            .{ .name = "transform_item_2", .type = .Reference }, // Reference to REPRESENTATION_ITEM
        },
    });

    const EntityType = enum {
        PRODUCT,
        PRODUCT_CONTEXT,
        APPLICATION_CONTEXT,
        PRODUCT_DEFINITION,
        PRODUCT_DEFINITION_CONTEXT,
        PRODUCT_DEFINITION_SHAPE,
        MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION,
        SHAPE_REPRESENTATION,
        ITEM_DEFINED_TRANSFORMATION,
    };

    const EntityTypes = .{
        Product,
        ProductContext,
        ApplicationContext,
        ProductDefinition,
        ProductDefinitionContext,
        ProductDefinitionShape,
        MechanicalDesignGeometricPresentationRepresentation,
        ShapeRepresentation,
        ItemDefinedTransformation,
    };

    fn stepTypeToOurType(comptime entity_type: EntityType) type {
        return switch (entity_type) {
            .PRODUCT => Product,
            .PRODUCT_CONTEXT => ProductContext,
            .APPLICATION_CONTEXT => ApplicationContext,
            .PRODUCT_DEFINITION => ProductDefinition,
            .PRODUCT_DEFINITION_CONTEXT => ProductDefinitionContext,
            .PRODUCT_DEFINITION_SHAPE => ProductDefinitionShape,
            .MECHANICAL_DESIGN_GEOMETRIC_PRESENTATION_REPRESENTATION => MechanicalDesignGeometricPresentationRepresentation,
            .SHAPE_REPRESENTATION => ShapeRepresentation,
            .ITEM_DEFINED_TRANSFORMATION => ItemDefinedTransformation,
        };
    }

    fn entityArrayFieldName(comptime entity_type: type) []const u8 {
        @setEvalBranchQuota(3000);
        var full_type_name: []const u8 = @typeName(entity_type);

        var it = std.mem.splitScalar(u8, full_type_name, '\"');
        _ = it.next();

        var type_name = it.next() orelse unreachable;
        var lower_case_name: []const u8 = .{std.ascii.toLower(type_name[0])} ++ type_name[1..] ++ "s";

        var snake_case_name: []const u8 = "";
        for (lower_case_name) |ch| {
            if (std.ascii.isUpper(ch)) {
                snake_case_name = snake_case_name ++ "_" ++ .{std.ascii.toLower(ch)};
            } else {
                snake_case_name = snake_case_name ++ .{ch};
            }
        }
        return snake_case_name;
    }

    fn CreateEntityArrayType(comptime entity_types: anytype) type {
        var fields: [entity_types.len]std.builtin.Type.StructField = undefined;
        for (entity_types, &fields) |et, *f|
            f.* = .{
                .name = entityArrayFieldName(et),
                .type = std.ArrayList(*et),
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };

        return @Type(.{
            .Struct = .{
                .layout = .Auto,
                .fields = fields[0..],
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_tuple = false,
            },
        });
    }

    const EntityArrayType = CreateEntityArrayType(EntityTypes);

    allocator: std.mem.Allocator,
    iso: [2]u16,
    file_description: FileDescription,
    file_name: FileName,
    file_schema: FileSchema,
    comment: ?[]const u8,

    // Only used for convenience, not actually responsible for memory
    entities_list: std.ArrayList(*anyopaque),

    entities: EntityArrayType,

    fn destroy(self: *StepData) void {
        self.allocator.free(self.file_description.description);

        self.allocator.free(self.file_name.name);
        self.allocator.free(self.file_name.author);
        self.allocator.free(self.file_name.organization);
        self.allocator.free(self.file_name.preprocessor_version);
        self.allocator.free(self.file_name.originating_system);
        self.allocator.free(self.file_name.authorization);

        self.allocator.free(self.file_schema.schema);
        if (self.file_schema.version) |v|
            self.allocator.free(v);
        if (self.comment) |c|
            self.allocator.free(c);

        self.entities_list.deinit();
        self.deinitEntities();
    }

    fn initEntities(self: *StepData) void {
        const fields: []const std.builtin.Type.StructField = @typeInfo(@TypeOf(self.entities)).Struct.fields;
        inline for (fields) |f|
            @field(self.entities, f.name) = (@TypeOf(@field(self.entities, f.name))).init(self.allocator);
    }

    fn deinitEntities(self: *StepData) void {
        const fields: []const std.builtin.Type.StructField = @typeInfo(@TypeOf(self.entities)).Struct.fields;
        inline for (fields) |f| {
            var entity_field = @field(self.entities, f.name);
            for (entity_field.items) |e| {
                e.deinit();
                self.allocator.destroy(e);
            }
            entity_field.deinit();
        }
    }
};

fn readFileSignature(step_data: *StepData, reader: anytype) !void {
    var sig: std.ArrayList(u8) = std.ArrayList(u8).init(step_data.allocator);
    defer sig.deinit();

    try fastStreamUntilDelimiter(reader, sig.writer(), '-');

    if (sig.items.len != 3 or sig.items[0] != 'I' or sig.items[1] != 'S' or sig.items[2] != 'O')
        return StepParseError.WrongSignature;
    sig.clearRetainingCapacity();

    try fastStreamUntilDelimiter(reader, sig.writer(), '-');
    step_data.iso[0] = try std.fmt.parseInt(@TypeOf(step_data.iso[0]), sig.items, 10);
    sig.clearRetainingCapacity();

    try fastStreamUntilDelimiter(reader, sig.writer(), ';');
    step_data.iso[1] = try std.fmt.parseInt(@TypeOf(step_data.iso[1]), sig.items, 10);

    try fastSkipUntilDelimiter(reader, '\n');
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

fn parseFileSchema(step_data: *StepData, content: []const u8) !void {
    var content_start: usize = std.mem.indexOfScalar(u8, content, '\'') orelse return error.OutOfBounds;

    var it = std.mem.splitScalar(u8, content[content_start + 1 ..], '{');

    var schema: []const u8 = it.next() orelse return error.OutOfBounds;
    var needs_to_be_trimmed: bool = schema[schema.len - 1] == ' ';
    var schema_end: usize = schema.len - (1 * @intFromBool(needs_to_be_trimmed));
    step_data.file_schema.schema = try step_data.allocator.dupe(u8, schema[0..schema_end]);

    step_data.file_schema.version = null;
    var version: []const u8 = it.next() orelse return;
    var version_end: usize = std.mem.indexOfScalar(u8, version, '}') orelse return error.OutOfBounds;

    var version_list = std.ArrayList(u32).init(step_data.allocator);
    var vit = std.mem.splitScalar(u8, version[1 .. version_end - 1], ' ');
    while (vit.next()) |v|
        try version_list.append(try std.fmt.parseInt(u32, v, 10));
    step_data.file_schema.version = try version_list.toOwnedSlice();
}

// https://www.openmymind.net/Performance-of-reading-a-file-line-by-line-in-Zig/
fn fastStreamUntilDelimiter(buffered: anytype, writer: anytype, delimiter: u8) !void {
    while (true) {
        const start = buffered.start;
        if (std.mem.indexOfScalar(u8, buffered.buf[start..buffered.end], delimiter)) |pos| {
            // we found the delimiter
            try writer.writeAll(buffered.buf[start .. start + pos]);
            // skip the delimiter
            buffered.start += pos + 1;
            return;
        } else {
            // we didn't find the delimiter, add everything to the output writer...
            try writer.writeAll(buffered.buf[start..buffered.end]);

            // ... and refill the buffer
            const n = try buffered.unbuffered_reader.read(buffered.buf[0..]);
            if (n == 0) {
                return error.EndOfStream;
            }
            buffered.start = 0;
            buffered.end = n;
        }
    }
}

fn fastSkipUntilDelimiter(buffered: anytype, delimiter: u8) !void {
    while (true) {
        const start = buffered.start;
        if (std.mem.indexOfScalar(u8, buffered.buf[start..buffered.end], delimiter)) |pos| {
            // skip the delimiter
            buffered.start += pos + 1;
            return;
        } else {
            // refill the buffer
            const n = try buffered.unbuffered_reader.read(buffered.buf[0..]);
            if (n == 0) {
                return error.EndOfStream;
            }
            buffered.start = 0;
            buffered.end = n;
        }
    }
}

fn readLine(line: *std.ArrayList(u8), reader: anytype) !void {
    try fastStreamUntilDelimiter(reader, line.writer(), '\n');
    if (line.items.len > 0 and line.getLast() == '\r')
        _ = line.pop();
}

fn parseHeader(step_data: *StepData, reader: anytype) !void {
    var line = std.ArrayList(u8).init(step_data.allocator);
    defer line.deinit();

    while (true) {
        readLine(&line, reader) catch break;
        defer line.clearRetainingCapacity();

        if (std.mem.eql(u8, line.items, "HEADER;"))
            break;
    }

    var header_lines = std.ArrayList([]u8).init(step_data.allocator);
    defer header_lines.deinit();
    defer {
        for (header_lines.items) |hl|
            step_data.allocator.free(hl);
    }

    while (true) {
        readLine(&line, reader) catch break;

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
            .FILE_SCHEMA => try parseFileSchema(step_data, hl[command_end_pos..]),
        }
    }
}

// Parses comments and data start command
fn parseTillDataStart(step_data: *StepData, reader: anytype) !void {
    step_data.comment = null;

    var line = std.ArrayList(u8).init(step_data.allocator);
    defer line.deinit();

    while (true) {
        readLine(&line, reader) catch break;
        defer line.clearRetainingCapacity();

        if (std.mem.eql(u8, line.items, "DATA;"))
            break;

        // For now only one comment is allowed for simplicity
        // Can't find any information how they suppose to be written
        // If there are comments at other lines, they should be treated as comment for specific STEP command
        if (step_data.comment != null)
            continue;

        var start_it = std.mem.splitSequence(u8, line.items, "/*");
        var start = start_it.next() orelse continue;
        start = start_it.next() orelse continue;

        var end_it = std.mem.splitSequence(u8, start, "*/");
        var comment: []const u8 = end_it.next() orelse continue;
        comment = std.mem.trim(u8, comment, " ");

        step_data.comment = step_data.allocator.dupe(u8, comment) catch unreachable;
    }
}

const ReadEntityInfo = struct {
    step_data: *StepData,
    line: *std.ArrayList(u8),
    args_start: usize,
    index: usize,
};

const StepArgumentIterator = struct {
    line: []const u8,

    pub fn next(self: *StepArgumentIterator) ?[]const u8 {
        if (self.line.len == 0)
            return null;

        var is_array = self.line[0] == '(';

        if (!is_array) {
            var comma_index = std.mem.indexOfScalar(u8, self.line, ',') orelse self.line.len;
            var arg: []const u8 = self.line[0..comma_index];
            self.line = self.line[@min(self.line.len, comma_index + 1)..];
            return arg;
        }

        var bracket_index = std.mem.indexOfScalar(u8, self.line, ')') orelse unreachable;
        var arg: []const u8 = self.line[1..bracket_index];
        self.line = self.line[@min(self.line.len, bracket_index + 2)..];
        return arg;
    }
};

fn readEntity(comptime Type: type, info: *ReadEntityInfo) void {
    const args_end: usize = std.mem.lastIndexOfScalar(u8, info.line.items, ')') orelse unreachable;

    var entity: *Type = info.step_data.allocator.create(Type) catch unreachable;
    entity.allocator = info.step_data.allocator;

    var it: StepArgumentIterator = .{ .line = info.line.items[info.args_start + 1 .. args_end] };
    entity.parseArgs(&it);
    @field(info.step_data.entities, StepData.entityArrayFieldName(Type)).append(entity) catch unreachable;

    if (info.step_data.entities_list.items.len <= info.index)
        info.step_data.entities_list.resize(info.index + 1) catch unreachable;
    info.step_data.entities_list.items[info.index] = @ptrCast(entity);
}

fn parseData(step_data: *StepData, reader: anytype) !void {
    step_data.entities_list = std.ArrayList(*anyopaque).init(step_data.allocator);
    step_data.initEntities();

    var line = std.ArrayList(u8).init(step_data.allocator);
    defer line.deinit();

    var read_entity_info: ReadEntityInfo = undefined;
    read_entity_info.step_data = step_data;
    read_entity_info.line = &line;

    while (true) {
        readLine(&line, reader) catch break;
        defer line.clearRetainingCapacity();

        if (std.mem.eql(u8, line.items, "ENDSEC;"))
            break;

        const equal_sign_index: usize = std.mem.indexOfScalar(u8, line.items, '=') orelse unreachable;
        const index: usize = try std.fmt.parseInt(usize, line.items[1..equal_sign_index], 10);

        const args_start: usize = (std.mem.indexOfScalar(u8, line.items[equal_sign_index..], '(') orelse unreachable) + equal_sign_index;
        const entity_type: StepData.EntityType = std.meta.stringToEnum(StepData.EntityType, line.items[equal_sign_index + 1 .. args_start]) orelse continue;

        read_entity_info.args_start = args_start;
        read_entity_info.index = index;

        inline for (@typeInfo(StepData.EntityType).Enum.fields) |et| {
            if (@as(StepData.EntityType, @enumFromInt(et.value)) == entity_type)
                readEntity(StepData.stepTypeToOurType(@enumFromInt(et.value)), &read_entity_info);
        }
    }
}

fn addStepToScene(step_data: *StepData, scene: *Scene) void {
    for (step_data.entities.products.items) |p| {
        var node: *SceneNode = scene.root.add();
        node.init(&UnionNodeType, p.d.id, &scene.root);
    }
}

pub fn importStepFile(path: []const u8) !void {
    const cwd: std.fs.Dir = std.fs.cwd();
    const file: std.fs.File = try cwd.openFile(path, .{ .mode = .read_only });
    defer file.close();

    var step_data: StepData = undefined;
    step_data.allocator = nyan.app.allocator;
    defer step_data.destroy();

    var reader = std.io.bufferedReader(file.reader());

    try readFileSignature(&step_data, &reader);
    try parseHeader(&step_data, &reader);
    try parseTillDataStart(&step_data, &reader);
    try parseData(&step_data, &reader);

    addStepToScene(&step_data, &Global.main_scene);
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
