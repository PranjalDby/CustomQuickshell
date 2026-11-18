#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="wallpaper-keyboard-rgb"
CONFIG_DIR="${HOME}/.config/matugen"
TEMPLATE_DIR="${CONFIG_DIR}/templates"
CACHE_DIR="${HOME}/.cache/${PLUGIN_NAME}"
BIN_DIR="${HOME}/.local/bin"
CONFIG_FILE="${CONFIG_DIR}/config.toml"
SCRIPT_PATH="${BIN_DIR}/${PLUGIN_NAME}-apply"
TEMPLATE_PATH="${TEMPLATE_DIR}/keyboard-rgb.txt"
MARKER="# BEGIN ${PLUGIN_NAME}"

PACKAGE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for cmd in matugen asusctl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$cmd" >&2
        exit 1
    fi
done

mkdir -p "$TEMPLATE_DIR" "$CACHE_DIR" "$BIN_DIR"
touch "$CONFIG_FILE"

if grep -Fq "$MARKER" "$CONFIG_FILE"; then
    echo "Wallpaper keyboard RGB integration is already installed."
    exit 0
fi

if grep -Fq '[templates.keyboard_rgb]' "$CONFIG_FILE"; then
    echo "A [templates.keyboard_rgb] section already exists in $CONFIG_FILE."
    echo "Please inspect it and merge the template settings manually; nothing was changed."
    exit 1
fi

cp "$PACKAGE_DIR/templates/keyboard-rgb.txt" "$TEMPLATE_PATH"
install -m 755 "$PACKAGE_DIR/scripts/wallpaper-keyboard-rgb-apply" "$SCRIPT_PATH"

BACKUP="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP"

# TOML basic strings: escape backslashes and double quotes in absolute paths.
toml_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

{
    printf '\n%s\n' "$MARKER"
    printf '[templates.keyboard_rgb]\n'
    printf 'input_path = %s\n' "$(toml_quote "$TEMPLATE_PATH")"
    printf 'output_path = %s\n' "$(toml_quote "$CACHE_DIR/color")"
    printf 'post_hook = %s\n' "$(toml_quote "$SCRIPT_PATH")"
    printf '# END wallpaper-keyboard-rgb\n'
} >> "$CONFIG_FILE"

echo "Installed wallpaper-to-keyboard RGB integration."
echo "Matugen config: $CONFIG_FILE"
echo "Backup:         $BACKUP"
echo
echo "DMS runs Matugen when its wallpaper changes. Change your wallpaper once"
echo "to trigger the first sync. Then inspect:"
echo "  $CACHE_DIR/sync.log"
