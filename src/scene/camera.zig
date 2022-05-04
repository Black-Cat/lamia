const nyan = @import("nyancore");
const nm = nyan.Math;

const ProjectionType = @import("../nodes/scene_settings/camera_settings.zig").ProjectionType;

pub const Camera = struct {
    target: nm.vec3,
    position: nm.vec3,
    up: nm.vec3, // Length is used as ortho camera scale

    zoomFn: fn (self: *Camera, dir: f32) void = zoomPerspective,

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

    pub fn setProjection(self: *Camera, projection: ProjectionType) void {
        switch (projection) {
            .orthographic => {
                self.zoomFn = zoomOrthographic;
            },
            .perspective => {
                self.zoomFn = zoomPerspective;
                self.up = nm.Vec3.normalize(self.up);
            },
        }
    }

    pub fn zoomPerspective(self: *Camera, dir: f32) void {
        var forward: nm.vec3 = self.position - self.target;

        const dst: f32 = nm.Vec3.norm(forward);
        const new_dst: f32 = dst + dir * @log(dst);

        forward = nm.Vec3.normalize(forward);
        self.position = self.target + forward * @splat(3, new_dst);
    }

    pub fn zoomOrthographic(self: *Camera, dir: f32) void {
        self.up = nm.Vec3.normalize(self.up) * @splat(3, nm.Vec3.norm(self.up) + dir);
    }
};
