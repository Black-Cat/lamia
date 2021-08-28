pub const NodeType = struct {
    name: []const u8,
    function_defenition: []const u8,

    init_data_fn: fn (buffer: **c_void, buffer_size: *usize) void,
};
