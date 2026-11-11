#!/bin/sh
dir="$HOME/Pictures/Screenshots"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
mkdir -p "$dir"

# slurp exits non-zero if you cancel with Esc, so stop quietly
region=$(slurp -d) || exit 0
grim -g "$region" "$file" && wl-copy < "$file" && notify-send "Screenshot saved" "$file"