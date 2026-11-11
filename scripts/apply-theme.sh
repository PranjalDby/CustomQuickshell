#!/bin/sh
# Usage: apply-theme.sh <theme-name>
QS="$HOME/.config/quickshell"
name="$1"
src="$QS/themes/$name.env"

[ -f "$src" ] || { echo "No theme named $name" >&2; exit 1; }

mkdir -p "$QS/state"
cp "$src" "$QS/state/colors.env"
printf %s "$name" > "$QS/state/theme"

# Build sed replacements: {{key}} for the value, {{key_raw}} for the value without #
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
exit 0