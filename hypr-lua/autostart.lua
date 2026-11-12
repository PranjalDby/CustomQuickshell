-- Startup commands. Run once per Hyprland session.
hl.on("hyprland.start", function()
    hl.exec_cmd("dms run")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
