#!/bin/sh
# Pick a theme from a menu and apply it everywhere (shell, borders, kitty, wallpaper, hooks).
QS="$HOME/.config/quickshell"
current=$(cat "$QS/state/theme" 2>/dev/null)

# List themes, marking the current one
list=$(ls "$QS/themes" 2>/dev/null | sed -n 's/\.env$//p' | sort | while read -r t; do
    if [ "$t" = "$current" ]; then echo "$t (current)"; else echo "$t"; fi
done)

[ -n "$list" ] || { notify-send "Theme" "No themes found in $QS/themes"; exit 1; }

menu() {
    if command -v wofi >/dev/null; then
        wofi --dmenu -i -p "Theme"
    elif command -v rofi >/dev/null; then
        rofi -dmenu -i -p "Theme"
    elif command -v fuzzel >/dev/null; then
        fuzzel --dmenu -p "Theme: "
    else
        echo "Install wofi, rofi, or fuzzel" >&2
        return 1
    fi
}

choice=$(printf '%s\n' "$list" | menu) || exit 0
choice=${choice% (current)}
[ -n "$choice" ] || exit 0

if "$QS/scripts/apply-theme.sh" "$choice"; then
    notify-send "Theme" "Applied $choice"
else
    notify-send "Theme" "Failed to apply $choice. Run apply-theme.sh in a terminal to see why."
fi