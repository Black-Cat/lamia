const NodeProperty = @import("node_property.zig").NodeProperty;

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
};