#!/bin/sh
# Usage:
#   apply-theme.sh <theme-name>           uses themes/<name>.env and its wallpaper
#   apply-theme.sh --env <file> <label>   uses a generated palette, leaves the wallpaper alone
QS="$HOME/.config/quickshell"

if [ "$1" = "--env" ]; then
    src="$2"; name="$3"; set_wall=0
else
    name="$1"; src="$QS/themes/$name.env"; set_wall=1
fi

[ -f "$src" ] || { echo "No palette file: $src" >&2; exit 1; }

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

render "$QS/templates/theme.lua.tmpl" "$HOME/.config/hypr/theme.lua"
render "$QS/templates/kitty.tmpl" "$HOME/.config/kitty/theme.conf"
render "$QS/templates/rofi-wallpaper.rasi.tmpl" "$HOME/.config/rofi/wallpaper.rasi"

hyprctl reload >/dev/null 2>&1
pkill -USR1 -x kitty 2>/dev/null

# Theme-only: set the theme's wallpaper, if it has one
if [ "$set_wall" = 1 ]; then
    wall=""
    for f in "$QS/wallpapers/$name".*; do
        [ -f "$f" ] && { wall="$f"; break; }
    done
    if [ -n "$wall" ] && command -v awww >/dev/null 2>&1; then
        if ! awww query >/dev/null 2>&1; then
            (awww-daemon >/dev/null 2>&1 &)
            sleep 1
        fi
        awww img "$wall" --transition-type fade --transition-duration 1 >/dev/null 2>&1
    fi
fi

# User hooks (dux shell, GTK, and so on), with the palette name as $1
for h in "$QS/hooks/"*.sh; do
    [ -x "$h" ] && "$h" "$name" >/dev/null 2>&1
done

exit 0