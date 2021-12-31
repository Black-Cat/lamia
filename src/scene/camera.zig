const nyan = @import("nyancore");
const nm = nyan.Math;

pub const Camera = struct {
    target: nm.vec3,
    position: nm.vec3,
    up: nm.vec3,

    // Dir expected to be normalized
    pub fn viewAlong(self: *Camera, dir: nm.vec3, up: nm.vec3) void {
        const dist: f32 = nm.Vec3.norm(self.position - self.target);
        self.position = self.target - dir * @splat(3, dist);
        self.up = up;
    }

    pub fn setDist(self: *Camera, dist: f32) void {
        const dir: nm.vec3 = nm.Vec3.normalize(self.position - self.target);
        self.position = self.target + dir * @splat(3, dist);
    }

    pub fn moveTargetTo(self: *Camera, pos: nm.vec3) void {
        const dir: nm.vec3 = self.position - self.target;
        self.target = pos;
        self.position = self.target - dir;
    }
};
