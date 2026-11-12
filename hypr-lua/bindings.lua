local mainMod = "SUPER"
local home = os.getenv("HOME")
local qs = home .. "/.config/quickshell/scripts"

-- Apps
hl.bind(mainMod .. " + E",       hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + Q",       hl.dsp.window.close())
hl.bind(mainMod .. " + F",       hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J",       hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

-- Focus and move
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "d" }))
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "d" }))

-- Workspaces 1 to 9
for i = 1, 9 do
    local ws = tostring(i)
    hl.bind(mainMod .. " + " .. ws,         hl.dsp.focus({ workspace = ws }))
    hl.bind(mainMod .. " + SHIFT + " .. ws, hl.dsp.window.move({ workspace = ws }))
end

-- Screenshots (SUPER+SHIFT+S avoids the Print key that DMS uses)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(qs .. "/screenshot.sh region"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(qs .. "/screenshot.sh full"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(qs .. "/screenshot.sh window"))

-- Theme, wallpaper, clipboard, session
hl.bind(mainMod .. " + ALT + W", hl.dsp.exec_cmd(qs .. "/wallpaper-select.sh"))
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd(qs .. "/theme-select.sh"))
hl.bind(mainMod .. " + L",       hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + ESCAPE",  hl.dsp.exec_cmd(qs .. "/logout.sh"))
