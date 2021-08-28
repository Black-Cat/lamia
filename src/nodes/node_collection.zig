const NodeType = @import("node_type.zig").NodeType;

pub const combinators = [_]NodeType{
    @import("combinators/intersection.zig").Intersection,
};
