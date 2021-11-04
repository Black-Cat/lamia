const nyan = @import("nyancore");
const nc = nyan.c;
const nm = nyan.Math;

const Camera = @import("../scene/camera.zig").Camera;

const mouse_button: u32 = 2;

const ControllerState = enum {
    not_active,
    orbiting,
    panning,
    zooming,
    dolly_zooming,
};

pub const ArcballCameraController = struct {
    state: ControllerState = .not_active,
    last_mouse_pos: nc.ImVec2 = undefined,

    camera: *Camera,

    // Must be called right after imgui element that controls camera
    pub fn handleInput(self: *ArcballCameraController) void {
        const io: *nc.ImGuiIO = nc.igGetIO();

        if (nc.igIsItemHovered(0))
            zoom(self.camera, -io.MouseWheel);

        if (nc.igIsItemClicked(mouse_button)) {
            nc.igGetMousePos(&self.last_mouse_pos);
            if (io.KeyShift and io.KeyCtrl) {
                self.state = .dolly_zooming;
            } else if (io.KeyShift) {
                self.state = .panning;
            } else if (io.KeyCtrl) {
                self.state = .zooming;
            } else {
                self.state = .orbiting;
            }
            return;
        }

        if (self.state != .not_active and !nc.igIsMouseDown(mouse_button)) {
            self.state = .not_active;
            return;
        }

        var cur_pos: nc.ImVec2 = undefined;
        nc.igGetMousePos(&cur_pos);

        const dir: nc.ImVec2 = .{
            .x = (cur_pos.x - self.last_mouse_pos.x) * 0.01,
            .y = (cur_pos.y - self.last_mouse_pos.y) * 0.01,
        };

        if (self.state == .orbiting) {
            const old_up: nm.vec3 = self.camera.up;
            var old_forward: nm.vec3 = self.camera.position - self.camera.target;
            const old_right: nm.vec3 = nm.Vec3.cross(old_forward, old_up);

            self.camera.up = nm.Vec3.rotate(self.camera.up, dir.x, old_up);
            self.camera.up = nm.Vec3.rotate(self.camera.up, dir.y, old_right);

            old_forward = nm.Vec3.rotate(old_forward, dir.x, old_up);
            old_forward = nm.Vec3.rotate(old_forward, dir.y, old_right);
            self.camera.position = self.camera.target + old_forward;
        } else if (self.state == .panning) {
            var offset: nm.vec3 = self.camera.up * @splat(3, dir.y);

            const forward: nm.vec3 = self.camera.position - self.camera.target;

            var right: nm.vec3 = nm.Vec3.cross(forward, self.camera.up);
            right = nm.Vec3.normalize(right) * @splat(3, -dir.x);

            offset += right;

            self.camera.position += offset;
            self.camera.target += offset;
        } else if (self.state == .zooming) {
            zoom(self.camera, dir.y);
        } else if (self.state == .dolly_zooming) {
            var forward: nm.vec3 = self.camera.target - self.camera.position;
            forward = nm.Vec3.normalize(forward);
            forward *= @splat(3, -dir.y);
            self.camera.target += forward;
            self.camera.position += forward;
        }

        self.last_mouse_pos = cur_pos;
    }

    fn zoom(camera: *Camera, dir: f32) void {
        var forward: nm.vec3 = camera.position - camera.target;

        const dst: f32 = nm.Vec3.norm(forward);
        const new_dst: f32 = dst + dir * @log(dst);

        forward = nm.Vec3.normalize(forward);
        camera.position = camera.target + forward * @splat(3, new_dst);
    }
};
