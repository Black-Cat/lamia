const nyan = @import("nyancore");
const nc = nyan.c;

const mainColors = [_]nc.ImVec4{
    .{ .x = 0.251, .y = 0.471, .z = 0.435, .w = 1.0 }, // Viridian
    .{ .x = 0.204, .y = 0.608, .z = 0.541, .w = 1.0 }, // ???
    .{ .x = 0.369, .y = 0.718, .z = 0.600, .w = 1.0 }, // Polished Pine
    .{ .x = 0.306, .y = 0.341, .z = 0.259, .w = 1.0 }, // Gray-Asparagus
    .{ .x = 0.173, .y = 0.353, .z = 0.333, .w = 1.0 }, // Dark Slate Gray
};

pub const UI = struct {
    nyanui: nyan.UI,

    pub fn init(self: *UI) void {
        self.nyanui.init("Nyan UI");
        self.nyanui.paletteFn = UI.palette;
    }

    pub fn deinit(self: *UI) void {}

    fn palette(col: nc.ImGuiCol_) nc.ImVec4 {
        return switch (@enumToInt(col)) {
            nc.ImGuiCol_Text => mainColors[4],
            nc.ImGuiCol_TextDisabled => mainColors[1],
            nc.ImGuiCol_WindowBg => mainColors[1],
            nc.ImGuiCol_ChildBg => mainColors[3],
            nc.ImGuiCol_PopupBg => mainColors[2],
            nc.ImGuiCol_Border => mainColors[3],
            nc.ImGuiCol_BorderShadow => mainColors[1],
            nc.ImGuiCol_FrameBg => mainColors[2],
            nc.ImGuiCol_FrameBgHovered => mainColors[1],
            nc.ImGuiCol_FrameBgActive => mainColors[0],
            nc.ImGuiCol_TitleBg => mainColors[3],
            nc.ImGuiCol_TitleBgActive => mainColors[4],
            nc.ImGuiCol_TitleBgCollapsed => mainColors[0],
            nc.ImGuiCol_MenuBarBg => mainColors[2],
            nc.ImGuiCol_ScrollbarBg => mainColors[2],
            nc.ImGuiCol_ScrollbarGrab => mainColors[4],
            nc.ImGuiCol_ScrollbarGrabHovered => mainColors[1],
            nc.ImGuiCol_ScrollbarGrabActive => mainColors[4],
            nc.ImGuiCol_CheckMark => mainColors[0],
            nc.ImGuiCol_SliderGrab => mainColors[2],
            nc.ImGuiCol_SliderGrabActive => mainColors[2],
            nc.ImGuiCol_Button => mainColors[2],
            nc.ImGuiCol_ButtonHovered => mainColors[3],
            nc.ImGuiCol_ButtonActive => mainColors[2],
            nc.ImGuiCol_Header => mainColors[0],
            nc.ImGuiCol_HeaderHovered => mainColors[0],
            nc.ImGuiCol_HeaderActive => mainColors[4],
            nc.ImGuiCol_Separator => mainColors[3],
            nc.ImGuiCol_SeparatorHovered => mainColors[3],
            nc.ImGuiCol_SeparatorActive => mainColors[3],
            nc.ImGuiCol_ResizeGrip => mainColors[3],
            nc.ImGuiCol_ResizeGripHovered => mainColors[2],
            nc.ImGuiCol_ResizeGripActive => mainColors[3],
            nc.ImGuiCol_Tab => mainColors[0],
            nc.ImGuiCol_TabHovered => mainColors[3],
            nc.ImGuiCol_TabActive => mainColors[3],
            nc.ImGuiCol_TabUnfocused => mainColors[3],
            nc.ImGuiCol_TabUnfocusedActive => mainColors[3],
            nc.ImGuiCol_PlotLines => mainColors[4],
            nc.ImGuiCol_PlotLinesHovered => mainColors[0],
            nc.ImGuiCol_PlotHistogram => mainColors[1],
            nc.ImGuiCol_PlotHistogramHovered => mainColors[3],
            nc.ImGuiCol_TableHeaderBg => mainColors[2],
            nc.ImGuiCol_TableBorderStrong => mainColors[2],
            nc.ImGuiCol_TableBorderLight => mainColors[3],
            nc.ImGuiCol_TableRowBg => mainColors[0],
            nc.ImGuiCol_TableRowBgAlt => mainColors[2],
            nc.ImGuiCol_TextSelectedBg => mainColors[0],
            nc.ImGuiCol_DragDropTarget => mainColors[3],
            nc.ImGuiCol_NavHighlight => mainColors[0],
            nc.ImGuiCol_NavWindowingHighlight => mainColors[1],
            nc.ImGuiCol_NavWindowingDimBg => mainColors[3],
            nc.ImGuiCol_ModalWindowDimBg => mainColors[2],
            else => @panic("Unknown Style"),
        };
    }
};
