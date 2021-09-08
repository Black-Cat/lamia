const nyan = @import("nyancore");
const nc = nyan.c;
const Global = @import("../global.zig");

pub const NodeProperty = struct {
    drawFn: fn (self: *const NodeProperty, data: *[]u8) bool,
    offset: usize,
    name: []const u8,

    prop_len: usize = undefined, // For strings, not always applicable
};

pub fn drawFloatProperty(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]f32 = @ptrCast([*c]f32, @alignCast(@alignOf(f32), &data.*[self.offset]));
    return nc.igInputFloat(self.name.ptr, data_ptr, 0.0, 0.0, "%.3f", nc.ImGuiInputTextFlags_EnterReturnsTrue);
}

pub fn drawFloat3Property(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]f32 = @ptrCast([*c]f32, @alignCast(@alignOf(f32), &data.*[self.offset]));
    return nc.igInputFloat3(self.name.ptr, data_ptr, "%.3f", nc.ImGuiInputTextFlags_EnterReturnsTrue);
}

pub fn drawU32Property(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]u32 = @ptrCast([*c]u32, @alignCast(@alignOf(u32), &data.*[self.offset]));
    return nc.igInputScalar(self.name.ptr, nc.ImGuiDataType_U32, data_ptr, null, null, "%u", nc.ImGuiInputTextFlags_EnterReturnsTrue);
}

// Put help text in the NodeProperty.name
pub fn drawHelpProperty(self: *const NodeProperty, data: *[]u8) bool {
    nc.igText(self.name.ptr);
    return false;
}

// Set NodeProperty.prop_len before using
pub fn drawCodeProperty(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]u8 = @ptrCast([*c]u8, &data.*[self.offset]);
    return nc.igInputTextMultiline(self.name.ptr, data_ptr, self.prop_len, .{ .x = 0, .y = 0 }, nc.ImGuiInputTextFlags_EnterReturnsTrue | nc.ImGuiInputTextFlags_AllowTabInput, null, null);
}

// Set NodeProperty.prop_len before using
pub fn drawTextProperty(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]u8 = @ptrCast([*c]u8, &data.*[self.offset]);
    return nc.igInputText(self.name.ptr, data_ptr, self.prop_len, nc.ImGuiInputTextFlags_EnterReturnsTrue, null, null);
}

pub fn drawColor3Property(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]f32 = @ptrCast([*c]f32, @alignCast(@alignOf(f32), &data.*[self.offset]));
    return nc.igColorEdit3(self.name.ptr, data_ptr, nc.ImGuiColorEditFlags_NoAlpha);
}

pub fn drawAxisMaskProperty(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]i32 = @ptrCast([*c]i32, @alignCast(@alignOf(i32), &data.*[self.offset]));

    var edited: bool = false;
    edited = nc.igCheckboxFlags_IntPtr("X", data_ptr, 1 << 0) or edited;
    nc.igSameLine(0, 10);
    edited = nc.igCheckboxFlags_IntPtr("Y", data_ptr, 1 << 1) or edited;
    nc.igSameLine(0, 10);
    edited = nc.igCheckboxFlags_IntPtr("Z", data_ptr, 1 << 2) or edited;
    nc.igSameLine(0, 10);
    nc.igText(self.name.ptr);

    return edited;
}

pub fn drawMaterialProperty(self: *const NodeProperty, data: *[]u8) bool {
    var data_ptr: [*c]i32 = @ptrCast([*c]i32, @alignCast(@alignOf(i32), &data.*[self.offset]));
    const current_index: i32 = data_ptr[0];

    var changed: bool = false;
    if (nc.igBeginCombo(self.name.ptr, &Global.main_scene.materials.children.items[@intCast(usize, current_index)].name, nc.ImGuiComboFlags_None)) {
        for (Global.main_scene.materials.children.items) |mat, i| {
            nc.igPushID_Ptr(mat);
            if (nc.igSelectable_Bool(&mat.name, i == current_index, nc.ImGuiSelectableFlags_None, .{ .x = 0, .y = 0 })) {
                data_ptr[0] = @intCast(i32, i);
                changed = true;
            }
            nc.igPopID();
        }
        nc.igEndCombo();
    }

    return changed;
}
