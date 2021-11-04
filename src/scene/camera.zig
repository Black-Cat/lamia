const nyan = @import("nyancore");
const nm = nyan.Math;

pub const Camera = struct {
    target: nm.vec3,
    position: nm.vec3,
    up: nm.vec3,
};
