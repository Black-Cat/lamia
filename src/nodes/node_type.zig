const std = @import("std");
const NodeProperty = @import("node_property.zig").NodeProperty;

pub const IterationContext = struct {
    pub const StackInfo = struct {
        index: usize,
        material: usize,
    };

    value_indexes: std.ArrayList(usize),
    last_value_set_index: usize,
    any_value_set: bool,

    points: std.ArrayList([]const u8),
    cur_point_name: []const u8,

    allocator: *std.mem.Allocator,

    pub fn create(allocator: *std.mem.Allocator) IterationContext {
        return .{
            .allocator = allocator,

            .value_indexes = std.ArrayList(usize).init(allocator),
            .last_value_set_index = undefined,
            .any_value_set = false,

            .points = std.ArrayList([]const u8).init(allocator),
            .cur_point_name = undefined,
        };
    }

    pub fn destroy(self: *IterationContext) void {
        self.value_indexes.deinit();
        self.points.deinit();
    }

    pub fn pushPointName(self: *IterationContext, name: []const u8) void {
        self.points.append(name) catch unreachable;
        self.cur_point_name = name;
    }

    pub fn popPointName(self: *IterationContext) void {
        self.allocator.free(self.cur_point_name);
        self.cur_point_name = self.points.pop();
    }

    pub fn pushStackInfo(index: usize, material: usize) void {
        self.value_indexes.append(.{ .index = index, .material = material }) catch unreachable;

        self.last_value_set_index = index;
        self.any_value_set = true;
    }

    pub fn dropPreviousValueIndexes(enter_index: usize) void {
        self.value_indexes.resize(enter_index + 1);

        const info: StackInfo = self.value_indexes.items[entex_index];
        self.last_value_set_index = info.index;
    }
};

fn appendNoMatCheck(exit_command: []const u8, buffer: *[]u8, mat_offset: usize, alloc: *std.mem.Allocator) []const u8 {
    return alloc.dupe(u8, exit_command) catch unreachable;
}

pub const NodeType = struct {
    name: []const u8,
    function_defenition: []const u8,

    properties: []const NodeProperty,

    init_data_fn: fn (buffer: *[]u8) void,

    has_edit_callback: bool = false,
    edit_callback: fn (buffer: *[]u8) void = undefined,

    has_deinit: bool = false,
    deinit_fn: fn (buffer: *[]u8) void = undefined,

    has_on_load: bool = false,
    on_load_fn: fn (buffer: *[]u8) void = undefined,

    external: bool = false, // Used only for File Scene Node

    enterCommandFn: fn (ctxt: *IterationContext, iter: usize, mat_offset: usize, buffer: *[]u8) []const u8 = undefined,
    exitCommandFn: fn (ctxt: *IterationContext, iter: usize, buffer: *[]u8) []const u8 = undefined,

    appendMatCheckFn: fn (exit_command: []const u8, buffer: *[]u8, mat_offset: usize, alloc: *std.mem.Allocator) []const u8 = appendNoMatCheck,
};
