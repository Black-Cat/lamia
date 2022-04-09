const std = @import("std");
const nyan = @import("nyancore");
const nc = nyan.c;

const open_link_command: []const u8 = switch (@import("builtin").target.os.tag) {
    .linux => "xdg-open",
    .windows => "start",
    .macos => "open",
    else => "xdg-open",
};

fn hyperlinkButton(link: [:0]const u8) void {
    if (nc.igButton(link, .{ .x = 0.0, .y = 0.0 })) {
        var args = std.ArrayList([]const u8).init(nyan.app.allocator);
        args.appendSlice(&[_][]const u8{ open_link_command, link }) catch unreachable;
        const child = std.ChildProcess.init(args.items, nyan.app.allocator) catch unreachable;
        _ = child.spawnAndWait() catch unreachable;
        child.deinit();
        args.deinit();
    }
}

fn awesomeThirdPartyLib(name: [:0]const u8, project_link: [:0]const u8) void {
    nc.igBulletText(name.ptr);
    nc.igSameLine(0.0, 10.0);
    hyperlinkButton(project_link);
}

pub fn drawAboutDialog() void {
    var close_modal: bool = true;
    if (nc.igBeginPopupModal("About", &close_modal, nc.ImGuiWindowFlags_None)) {
        nc.igText("lamia");
        nc.igText("Project Page:");
        nc.igSameLine(0.0, 10.0);
        hyperlinkButton("https://github.com/Black-Cat/lamia");

        nc.igText("Awesome third party libraries used in this program:");
        awesomeThirdPartyLib("cimgui", "https://github.com/cimgui/cimgui");
        awesomeThirdPartyLib("dear imgui", "https://github.com/ocornut/imgui");
        awesomeThirdPartyLib("enet", "http://enet.bespin.org");
        awesomeThirdPartyLib("glfw", "https://github.com/glfw/glfw");
        awesomeThirdPartyLib("glslang", "https://github.com/KronosGroup/glslang");
        awesomeThirdPartyLib("vulkan-zig", "https://github.com/Snektron/vulkan-zig");

        nc.igText("If you have an issue or suggestion please report it here");
        hyperlinkButton("https://github.com/Black-Cat/lamia/issues");
        nc.igText("To contact author directly: email - iblackcatw@gmail.com or discord \"Black Cat!#5337\"");

        if (nc.igButton("Close", .{ .x = 0.0, .y = 0.0 }))
            nc.igCloseCurrentPopup();
        nc.igEndPopup();
    }
}
