const nyan = @import("nyancore");
const nc = nyan.c;

const Allocator = @import("std").mem.Allocator;
const drawAboutDialog = @import("about.zig").drawAboutDialog;
const drawExportSdfDialog = @import("export_sdf.zig").drawExportSdfDialog;
const drawExportGlbDialog = @import("export_glb.zig").drawExportGlbDialog;
const SceneNode = @import("../scene/scene_node.zig").SceneNode;
const Global = @import("../global.zig");
const GizmoStorage = @import("widgets/viewport_gizmos.zig").GizmoStorage;

const Console = @import("widgets/console.zig").Console;
const Inspector = @import("widgets/inspector.zig").Inspector;
const Materials = @import("widgets/materials.zig").Materials;
const Monitor = @import("widgets/monitor.zig").Monitor;
const SceneTree = @import("widgets/scene_tree.zig").SceneTree;
const ViewportSpace = @import("widgets/viewport_space.zig").ViewportSpace;

pub const mainColors = [_]nc.ImVec4{
    .{ .x = 0.251, .y = 0.471, .z = 0.435, .w = 1.0 }, // Viridian
    .{ .x = 0.204, .y = 0.608, .z = 0.541, .w = 1.0 }, // ???
    .{ .x = 0.369, .y = 0.718, .z = 0.600, .w = 1.0 }, // Polished Pine
    .{ .x = 0.306, .y = 0.341, .z = 0.259, .w = 1.0 }, // Gray-Asparagus
    .{ .x = 0.173, .y = 0.353, .z = 0.333, .w = 1.0 }, // Dark Slate Gray
};

fn mainColorWithTransparency(ind: usize, transparency: f32) nc.ImVec4 {
    var col = mainColors[ind];
    col.w = transparency;
    return col;
}

pub const UI = struct {
    nyanui: nyan.UI,

    dockspace: nyan.Widgets.DockSpace,
    windows: [5]*nyan.Widgets.Window,

    nyanui_system_init_fn: fn (system: *nyan.System, app: *nyan.Application) void,
    nyanui_system_deinit_fn: fn (system: *nyan.System) void,

    console: Console,
    inspector: Inspector,
    materials: Materials,
    monitor: Monitor,
    scene_tree: SceneTree,
    viewport_space: ViewportSpace,

    selected_scene_node: ?*SceneNode,
    gizmo_storage: GizmoStorage,

    pub fn init(self: *UI, allocator: Allocator) void {
        self.nyanui.init("Nyan UI", allocator);
        self.nyanui.paletteFn = UI.palette;
        self.nyanui.drawFn = UI.draw;

        self.nyanui_system_init_fn = self.nyanui.system.init;
        self.nyanui.system.init = systemInit;

        self.nyanui_system_deinit_fn = self.nyanui.system.deinit;
        self.nyanui.system.deinit = systemDeinit;

        self.dockspace.init("DockSpace", initLayout);
        self.nyanui.dockspace = &self.dockspace;

        self.selected_scene_node = null;

        self.console.init();
        self.inspector.init(&self.selected_scene_node, &self.gizmo_storage);
        self.scene_tree.init(&self.selected_scene_node);
        self.monitor.init();
        self.materials.init(&self.selected_scene_node);
        self.viewport_space.init(&self.nyanui, &self.gizmo_storage);

        self.windows[0] = &self.materials.window;
        self.windows[1] = &self.inspector.window;
        self.windows[2] = &self.scene_tree.window;
        self.windows[3] = &self.console.window;
        self.windows[4] = &self.monitor.window;

        self.gizmo_storage = undefined;
        self.gizmo_storage.init(allocator);
    }

    fn systemInit(system: *nyan.System, app: *nyan.Application) void {
        const nyanui: *nyan.UI = @fieldParentPtr(nyan.UI, "system", system);
        const self: *UI = @fieldParentPtr(UI, "nyanui", nyanui);

        self.nyanui_system_init_fn(system, app);

        Global.main_scene.recompile();

        self.viewport_space.window.widget.init(&self.viewport_space.window.widget);

        for (self.windows) |w|
            w.widget.init(&w.widget);
    }

    fn systemDeinit(system: *nyan.System) void {
        const nyanui: *nyan.UI = @fieldParentPtr(nyan.UI, "system", system);
        const self: *UI = @fieldParentPtr(UI, "nyanui", nyanui);

        self.gizmo_storage.deinit();

        for (self.windows) |w|
            w.widget.deinit(&w.widget);

        self.viewport_space.window.widget.deinit(&self.viewport_space.window.widget);

        self.dockspace.deinit();

        self.nyanui_system_deinit_fn(system);
    }

    fn initLayout(main_id: nc.ImGuiID) void {
        var dock_main_id: nc.ImGuiID = main_id;

        var dock_id_left_top: nc.ImGuiID = nc.igDockBuilderSplitNode(dock_main_id, nc.ImGuiDir_Left, 0.2, null, &dock_main_id);
        var dock_id_left_bottom: nc.ImGuiID = nc.igDockBuilderSplitNode(dock_id_left_top, nc.ImGuiDir_Down, 0.5, null, &dock_id_left_top);
        var dock_id_right: nc.ImGuiID = nc.igDockBuilderSplitNode(dock_main_id, nc.ImGuiDir_Right, 0.2, null, &dock_main_id);
        var dock_id_bottom_left: nc.ImGuiID = nc.igDockBuilderSplitNode(dock_main_id, nc.ImGuiDir_Down, 0.2, null, &dock_main_id);
        var dock_id_bottom_right: nc.ImGuiID = nc.igDockBuilderSplitNode(dock_id_bottom_left, nc.ImGuiDir_Right, 0.5, null, &dock_id_bottom_left);

        nc.igDockBuilderDockWindow("Viewport Space", dock_main_id);
        nc.igDockBuilderDockWindow("Scene Tree", dock_id_left_top);
        nc.igDockBuilderDockWindow("Materials", dock_id_left_bottom);
        nc.igDockBuilderDockWindow("Inspector", dock_id_right);
        nc.igDockBuilderDockWindow("Console", dock_id_bottom_left);
        nc.igDockBuilderDockWindow("Monitor", dock_id_bottom_right);

        nc.igDockBuilderFinish(main_id);
    }

    fn drawMenuBar(self: *UI) void {
        var open_about_popup: bool = false;
        var open_export_sdf_popup: bool = false;
        var open_export_glb_popup: bool = false;

        if (nc.igBeginMenuBar()) {
            if (nc.igBeginMenu("Windows", true)) {
                for (self.windows) |w|
                    _ = nc.igMenuItem_BoolPtr(w.strId, "", &w.open, true);
                nc.igEndMenu();
            }

            if (nc.igBeginMenu("About", true)) {
                open_about_popup = true;
                nc.igEndMenu();
            }

            if (nc.igBeginMenu("Export", true)) {
                _ = nc.igMenuItem_BoolPtr("Export nyan sdf", "", &open_export_sdf_popup, true);
                _ = nc.igMenuItem_BoolPtr("Export glb mesh", "", &open_export_glb_popup, true);
                nc.igEndMenu();
            }

            if (nc.igBeginMenu("Settings", true)) {
                var vsync: bool = nyan.app.config.getBool("swapchain_vsync", false);
                if (nc.igMenuItem_BoolPtr("VSync", "", &vsync, true)) {
                    nyan.app.config.putBool("swapchain_vsync", vsync);
                    nyan.global_render_graph.final_swapchain.recreateWithSameSize() catch |err| {
                        nyan.vkw.printVulkanError("Can't recreate swapchain after changing vsync", err, nyan.app.allocator);
                    };
                }
                nc.igEndMenu();
            }

            nc.igEndMenuBar();
        }

        if (open_about_popup)
            nc.igOpenPopup("About", nc.ImGuiPopupFlags_None);
        drawAboutDialog();

        if (open_export_sdf_popup)
            nc.igOpenPopup("Export to NyanSDF", nc.ImGuiPopupFlags_None);
        drawExportSdfDialog();

        if (open_export_glb_popup)
            nc.igOpenPopup("Export to GLB Mesh", nc.ImGuiPopupFlags_None);
        drawExportGlbDialog();
    }

    fn draw(nyanui: *nyan.UI) void {
        const self: *UI = @fieldParentPtr(UI, "nyanui", nyanui);

        self.drawMenuBar();
        self.viewport_space.window.widget.draw(&self.viewport_space.window.widget);
        for (self.windows) |w|
            w.widget.draw(&w.widget);
    }

    fn palette(col: nc.ImGuiCol_) nc.ImVec4 {
        return switch (col) {
            nc.ImGuiCol_Text => .{ .x = 0.0, .y = 0.1, .z = 0.1, .w = 1.0 },
            nc.ImGuiCol_TextDisabled => mainColors[1],
            nc.ImGuiCol_WindowBg => mainColors[3],
            nc.ImGuiCol_ChildBg => mainColors[3],
            nc.ImGuiCol_PopupBg => mainColors[2],
            nc.ImGuiCol_Border => mainColors[1],
            nc.ImGuiCol_BorderShadow => mainColors[1],
            nc.ImGuiCol_FrameBg => mainColors[4],
            nc.ImGuiCol_FrameBgHovered => mainColors[1],
            nc.ImGuiCol_FrameBgActive => mainColors[2],
            nc.ImGuiCol_TitleBg => mainColors[0],
            nc.ImGuiCol_TitleBgActive => mainColors[1],
            nc.ImGuiCol_TitleBgCollapsed => mainColors[2],
            nc.ImGuiCol_MenuBarBg => mainColors[4],
            nc.ImGuiCol_ScrollbarBg => mainColors[2],
            nc.ImGuiCol_ScrollbarGrab => mainColors[1],
            nc.ImGuiCol_ScrollbarGrabHovered => mainColors[1],
            nc.ImGuiCol_ScrollbarGrabActive => mainColors[4],
            nc.ImGuiCol_CheckMark => mainColors[0],
            nc.ImGuiCol_SliderGrab => mainColors[3],
            nc.ImGuiCol_SliderGrabActive => mainColors[4],
            nc.ImGuiCol_Button => mainColors[0],
            nc.ImGuiCol_ButtonHovered => mainColors[1],
            nc.ImGuiCol_ButtonActive => mainColors[2],
            nc.ImGuiCol_Header => mainColors[0],
            nc.ImGuiCol_HeaderHovered => mainColors[1],
            nc.ImGuiCol_HeaderActive => mainColors[2],
            nc.ImGuiCol_Separator => mainColors[0],
            nc.ImGuiCol_SeparatorHovered => mainColors[1],
            nc.ImGuiCol_SeparatorActive => mainColors[2],
            nc.ImGuiCol_ResizeGrip => mainColors[0],
            nc.ImGuiCol_ResizeGripHovered => mainColors[1],
            nc.ImGuiCol_ResizeGripActive => mainColors[2],
            nc.ImGuiCol_Tab => mainColors[0],
            nc.ImGuiCol_TabHovered => mainColors[1],
            nc.ImGuiCol_TabActive => mainColors[2],
            nc.ImGuiCol_TabUnfocused => mainColorWithTransparency(1, 0.8),
            nc.ImGuiCol_TabUnfocusedActive => mainColorWithTransparency(2, 0.8),
            nc.ImGuiCol_PlotLines => mainColors[0],
            nc.ImGuiCol_PlotLinesHovered => mainColors[1],
            nc.ImGuiCol_PlotHistogram => mainColors[1],
            nc.ImGuiCol_PlotHistogramHovered => mainColors[0],
            nc.ImGuiCol_TableHeaderBg => mainColors[4],
            nc.ImGuiCol_TableBorderStrong => mainColors[1],
            nc.ImGuiCol_TableBorderLight => mainColors[4],
            nc.ImGuiCol_TableRowBg => mainColors[0],
            nc.ImGuiCol_TableRowBgAlt => mainColors[4],
            nc.ImGuiCol_TextSelectedBg => mainColors[1],
            nc.ImGuiCol_DragDropTarget => mainColors[2],
            nc.ImGuiCol_NavHighlight => mainColors[3],
            nc.ImGuiCol_NavWindowingHighlight => mainColors[3],
            nc.ImGuiCol_NavWindowingDimBg => mainColors[0],
            nc.ImGuiCol_ModalWindowDimBg => mainColorWithTransparency(1, 0.5),
            else => @panic("Unknown Style"),
        };
    }
};
