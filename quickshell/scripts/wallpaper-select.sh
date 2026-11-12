#!/bin/sh
# Wallpaper picker: rofi thumbnail grid. Uses dux shell (dms) when present, otherwise awww + our palette.
DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
QS="$HOME/.config/quickshell"
STATE="$QS/state"
THUMBS="$HOME/.cache/wallpaper-thumbs"
THEME="$HOME/.config/rofi/wallpaper.rasi"
LOG="$HOME/.cache/wallpaper-select.log"
mkdir -p "$STATE" "$THUMBS" "$(dirname "$LOG")"

log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$LOG"; }
log "--- picker opened"

[ -d "$DIR" ] || { notify-send "Wallpaper" "Folder not found: $DIR"; exit 1; }

list=$(find -L "$DIR" -maxdepth 2 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
[ -n "$list" ] || { notify-send "Wallpaper" "No images in $DIR"; exit 1; }

IM=""
if command -v magick >/dev/null; then IM="magick"
elif command -v convert >/dev/null; then IM="convert"
fi

thumb_for() {
    f="$1"
    [ -n "$IM" ] || { printf '%s\n' "$f"; return; }
    key=$(printf '%s' "$f" | md5sum | cut -d' ' -f1)
    t="$THUMBS/$key.jpg"
    if [ ! -s "$t" ]; then
        $IM "$f[0]" -filter Lanczos -thumbnail 760x428^ -gravity center -extent 760x428 \
            -unsharp 0x0.6+0.6+0 -quality 95 "$t" 2>/dev/null || { rm -f "$t"; printf '%s\n' "$f"; return; }
    fi
    printf '%s\n' "$t"
}

if [ -f "$THEME" ]; then
    choice=$(printf '%s\n' "$list" | while IFS= read -r f; do
        printf '%s\000icon\037%s\n' "$(basename "$f")" "$(thumb_for "$f")"
    done | rofi -dmenu -show-icons -i -p "Wallpaper" -theme "$THEME") || { log "rofi cancelled"; exit 0; }
else
    choice=$(printf '%s\n' "$list" | while IFS= read -r f; do
        printf '%s\000icon\037%s\n' "$(basename "$f")" "$(thumb_for "$f")"
    done | rofi -dmenu -show-icons -i -p "Wallpaper") || { log "rofi cancelled"; exit 0; }
fi
log "choice='$choice'"
[ -n "$choice" ] || exit 0

path=$(printf '%s\n' "$list" | while IFS= read -r f; do
    [ "$(basename "$f")" = "$choice" ] && { printf '%s\n' "$f"; break; }
done)
log "path='$path'"
[ -f "$path" ] || { notify-send "Wallpaper" "Could not find $choice"; log "no file for choice"; exit 1; }

# dux shell owns the wallpaper and its palette
if command -v dms >/dev/null 2>&1; then
    if dms ipc call wallpaper set "$path" >>"$LOG" 2>&1; then
        printf '%s\n' "$path" > "$STATE/wallpaper"
        notify-send "Wallpaper" "Set $choice"
        log "dms ok"
    else
        notify-send "Wallpaper" "dms could not set $choice. Is 'dms run' running?"
        log "dms failed"
        exit 1
    fi
    exit 0
fi

# Fallback without dux shell: awww plus our own palette
if ! awww query >/dev/null 2>&1; then
    setsid awww-daemon >/dev/null 2>&1 < /dev/null &
    for i in 1 2 3 4 5 6 7 8 9 10; do
        awww query >/dev/null 2>&1 && break
        sleep 0.3
    done
fi

if err=$(awww img "$path" --transition-type fade --transition-duration 1 2>&1); then
    printf '%s\n' "$path" > "$STATE/wallpaper"
    notify-send "Wallpaper" "Set $choice"
    log "ok"

    if "$QS/scripts/palette-from-image.sh" "$path" "$STATE/wallpaper.env" 2>>"$LOG"; then
        if "$QS/scripts/apply-theme.sh" --env "$STATE/wallpaper.env" "wallpaper" >>"$LOG" 2>&1; then
            log "palette applied"
        else
            log "palette apply failed"
            notify-send "Palette" "Apply failed. See ~/.cache/wallpaper-select.log"
        fi
    else
        log "palette generation failed"
    fi
else
    notify-send "Wallpaper" "awww failed: $err"
    log "awww failed: $err"
    exit 1
fi