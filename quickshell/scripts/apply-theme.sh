#!/bin/sh
# Usage: apply-theme.sh <theme-name>
QS="$HOME/.config/quickshell"
name="$1"
src="$QS/themes/$name.env"

[ -f "$src" ] || { echo "No theme named $name" >&2; exit 1; }

mkdir -p "$QS/state"
cp "$src" "$QS/state/colors.env"
printf %s "$name" > "$QS/state/theme"

expr=""
for key in bg surface fg muted accent red green yellow; do
    val=$(sed -n "s/^$key=//p" "$src")
    raw=${val#\#}
    expr="$expr -e s|{{$key}}|$val|g -e s|{{${key}_raw}}|$raw|g"
done

render() {
    mkdir -p "$(dirname "$2")"
    sed $expr "$1" > "$2"
}

render "$QS/templates/hyprland.tmpl" "$HOME/.config/hypr/theme.conf"
render "$QS/templates/kitty.tmpl" "$HOME/.config/kitty/theme.conf"

hyprctl reload >/dev/null 2>&1
pkill -USR1 -x kitty 2>/dev/null

# Wallpaper: wallpapers/<theme>.<ext>, if one exists
wall=""
for f in "$QS/wallpapers/$name".*; do
    [ -f "$f" ] && { wall="$f"; break; }
done

if [ -n "$wall" ] && command -v swww >/dev/null 2>&1; then
    if ! swww query >/dev/null 2>&1; then
        (swww-daemon >/dev/null 2>&1 &)
        sleep 1
    fi
    swww img "$wall" --transition-type fade --transition-duration 1 >/dev/null 2>&1
fi

exit 0