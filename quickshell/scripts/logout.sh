#!/bin/sh
# Ends the Hyprland session. Tries uwsm first (Omarchy), then systemd-logind, then Hyprland itself.
LOG="$HOME/.config/quickshell/state/logout.log"
mkdir -p "$(dirname "$LOG")"
echo "--- $(date) logout requested (session=$XDG_SESSION_ID)" >> "$LOG"

if command -v uwsm >/dev/null 2>&1 && uwsm stop >> "$LOG" 2>&1; then
    exit 0
fi
if [ -n "$XDG_SESSION_ID" ] && loginctl terminate-session "$XDG_SESSION_ID" >> "$LOG" 2>&1; then
    exit 0
fi
hyprctl dispatch exit >> "$LOG" 2>&1