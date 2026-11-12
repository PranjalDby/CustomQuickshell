-- Monitor layout. Find your names with: hyprctl monitors
-- Examples:
--   hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "0x0", scale = 1 })
--   hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1 })
-- Mirror a second screen to the first:
--   hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
