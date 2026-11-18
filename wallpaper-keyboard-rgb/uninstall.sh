#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/matugen/config.toml"
TEMPLATE_PATH="${HOME}/.config/matugen/templates/keyboard-rgb.txt"
SCRIPT_PATH="${HOME}/.local/bin/wallpaper-keyboard-rgb-apply"
CACHE_DIR="${HOME}/.cache/wallpaper-keyboard-rgb"

if [[ -f "$CONFIG_FILE" ]] && grep -Fq '# BEGIN wallpaper-keyboard-rgb' "$CONFIG_FILE"; then
    python3 - "$CONFIG_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
start = "# BEGIN wallpaper-keyboard-rgb"
end = "# END wallpaper-keyboard-rgb"
before, marker, rest = text.partition(start)
if marker:
    block, end_marker, after = rest.partition(end)
    if end_marker:
        text = before.rstrip() + ("\n" if before.strip() else "") + after.lstrip("\n")
        path.write_text(text)
PY
fi

rm -f "$TEMPLATE_PATH" "$SCRIPT_PATH"
rm -rf "$CACHE_DIR"
echo "Removed wallpaper keyboard RGB integration files."
echo "Your previous Matugen config backups were left untouched."
