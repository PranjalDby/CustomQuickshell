#!/bin/sh
# Toggles mirroring of eDP-1 onto HDMI-A-1. Uses literal paths so Hyprland's environment can't change them.
F=/home/pranjal/.config/hypr/mirror.lua
STATE=/home/pranjal/.config/quickshell/state/mirror
mkdir -p /home/pranjal/.config/quickshell/state

if [ -f "$STATE" ]; then
    rm -f "$STATE"
    printf -- '-- Mirror off\n' > "$F"
    notify-send "Display" "Mirror off"
else
    touch "$STATE"
    printf '%s\n' 'hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.00", position = "0x0", scale = 1, mirror = "eDP-1" })' > "$F"
    notify-send "Display" "Mirror on"
fi

hyprctl reload >/dev/null 2>&1
