const std = @import("std");
const NodeType = @import("node_type.zig").NodeType;

pub const combinators = [_]NodeType{
    @import("combinators/intersection.zig").Intersection,
    @import("combinators/smooth_intersection.zig").SmoothIntersection,
    @import("combinators/smooth_subtraction.zig").SmoothSubtraction,
    @import("combinators/smooth_union.zig").SmoothUnion,
    @import("combinators/subtraction.zig").Subtraction,
    @import("combinators/union.zig").Union,
};

pub const materials = [_]NodeType{
    @import("materials/custom_material.zig").CustomMaterial,
    @import("materials/lambert.zig").Lambert,
    @import("materials/oren_nayar.zig").OrenNayar,
};

pub const modifiers = [_]NodeType{
    @import("modifiers/bend.zig").Bend,
    @import("modifiers/displacement.zig").Displacement,
    @import("modifiers/displacement_noise.zig").DisplacementNoise,
    @import("modifiers/elongate.zig").Elongate,
    @import("modifiers/finite_repetition.zig").FiniteRepetition,
    @import("modifiers/infinite_repetition.zig").InfiniteRepetition,
    @import("modifiers/onion.zig").Onion,
    @import("modifiers/rounding.zig").Rounding,
    @import("modifiers/scale.zig").Scale,
    @import("modifiers/symmetry.zig").Symmetry,
    @import("modifiers/transform.zig").Transform,
    @import("modifiers/twist.zig").Twist,
    @import("modifiers/wrinkles.zig").Wrinkles,
};

pub const scene_settings = [_]NodeType{
    @import("scene_settings/camera_settings.zig").CameraSettings,
    @import("scene_settings/environment_settings.zig").EnvironmentSettings,
};

pub const special = [_]NodeType{
    @import("special/custom_node.zig").CustomNode,
    @import("special/file_scene_node.zig").FileSceneNode,
};

pub const surfaces = [_]NodeType{
    @import("surfaces/bezier_curve.zig").BezierCurve,
    @import("surfaces/bounding_box.zig").BoundingBox,
    @import("surfaces/box.zig").Box,
    @import("surfaces/capped_cone.zig").CappedCone,
    @import("surfaces/capped_cylinder.zig").CappedCylinder,
    @import("surfaces/capped_torus.zig").CappedTorus,
    @import("surfaces/capsule.zig").Capsule,
    @import("surfaces/cone.zig").Cone,
    @import("surfaces/ellipsoid.zig").Ellipsoid,
    @import("surfaces/hexagonal_prism.zig").HexagonalPrism,
    @import("surfaces/infinite_cone.zig").InfiniteCone,
    @import("surfaces/infinite_cylinder.zig").InfiniteCylinder,
    @import("surfaces/link.zig").Link,
    @import("surfaces/octahedron.zig").Octahedron,
    @import("surfaces/plane.zig").Plane,
    @import("surfaces/pyramid.zig").Pyramid,
    @import("surfaces/quad.zig").Quad,
    @import("surfaces/rhombus.zig").Rhombus,
    @import("surfaces/round_box.zig").RoundBox,
    @import("surfaces/round_cone.zig").RoundCone,
    @import("surfaces/rounded_cylinder.zig").RoundedCylinder,
    @import("surfaces/solid_angle.zig").SolidAngle,
    @import("surfaces/sphere.zig").Sphere,
    @import("surfaces/torus.zig").Torus,
    @import("surfaces/triangle.zig").Triangle,
    @import("surfaces/triangular_prism.zig").TriangularPrism,
    @import("surfaces/vertical_capped_cone.zig").VerticalCappedCone,
    @import("surfaces/vertical_capped_cylinder.zig").VerticalCappedCylinder,
    @import("surfaces/vertical_capsule.zig").VerticalCapsule,
    @import("surfaces/vertical_round_cone.zig").VerticalRoundCone,
};

const NodeKV = struct {
    @"0": []const u8,
    @"1": *const NodeType,
};

fn collectionToKV(comptime collection: []const NodeType) []NodeKV {
    var kvs = [1]NodeKV{undefined} ** collection.len;
    for (collection) |*node_type, i|
        kvs[i] = .{ .@"0" = node_type.name, .@"1" = node_type };
    return kvs[0..];
}

pub const node_map = std.ComptimeStringMap(
    *const NodeType,
    collectionToKV(combinators[0..]) ++
        collectionToKV(materials[0..]) ++
        collectionToKV(modifiers[0..]) ++
        collectionToKV(scene_settings[0..]) ++
        collectionToKV(special[0..]) ++
        collectionToKV(surfaces[0..]),
);
