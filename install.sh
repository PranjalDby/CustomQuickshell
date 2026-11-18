#!/usr/bin/env bash
# Installs the custom desktop pieces onto an Arch + Hyprland + DMS system.
# Safe to re-run. Backs up what it replaces. Keeps state, wallpapers, and DMS's files.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
QS="$HOME/.config/quickshell"
HYPR="$HOME/.config/hypr"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/custom-quickshell-backup-$STAMP"

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------ preflight
[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not root."
command -v pacman >/dev/null || die "pacman not found. This installer is for Arch-based systems."
for d in quickshell bar settings window-tool; do
    [ -d "$REPO/$d" ] || die "Missing $REPO/$d"
done
[ -f "$REPO/quickshell/shell.qml" ] || die "Missing $REPO/quickshell/shell.qml"

command -v dms >/dev/null || warn "DMS (dms) not found. The bar, launcher, and wallpaper picker expect DankMaterialShell."
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || warn "Not inside a Hyprland session. Files are installed, but reload and start are skipped."

# ------------------------------------------------------------ packages
say "Installing packages"
PKGS=(
    quickshell awww rofi imagemagick jq slurp grim wl-clipboard libnotify wev python
    brightnessctl hyprlock kitty ttf-jetbrains-mono-nerd
    pipewire pipewire-pulse pipewire-alsa wireplumber
    networkmanager bluez bluez-utils
)
sudo pacman -S --needed --noconfirm "${PKGS[@]}" || {
    helper=$(command -v yay || command -v paru || true)
    [ -n "$helper" ] || die "Package install failed. Install quickshell and awww from the AUR, then re-run."
    "$helper" -S --needed --noconfirm "${PKGS[@]}"
}

# ------------------------------------------------------------ services
say "Enabling services"
sudo systemctl enable --now bluetooth.service 2>/dev/null || warn "Could not enable bluetooth.service"
systemctl is-active --quiet NetworkManager || sudo systemctl enable --now NetworkManager.service 2>/dev/null \
    || warn "Could not enable NetworkManager (the Wi-Fi menu needs it)"
sudo usermod -aG video "$USER" 2>/dev/null || warn "Could not add $USER to the video group (brightness keys need it)"

# ------------------------------------------------------------ backup
say "Backing up replaced files to $BACKUP"
mkdir -p "$BACKUP"
[ -d "$QS" ] && cp -a "$QS" "$BACKUP/quickshell"
[ -f "$HYPR/hyprland.lua" ] && cp -a "$HYPR/hyprland.lua" "$BACKUP/"
[ -f "$HYPR/customshell.lua" ] && cp -a "$HYPR/customshell.lua" "$BACKUP/"

# ------------------------------------------------------------ quickshell support files
say "Installing scripts, templates, and themes into $QS"
mkdir -p "$QS/state" "$QS/wallpapers" "$QS/plugins"

# Old modules and hooks from the retired shell. Removed, since the backup holds them.
rm -rf "$QS/modules" "$QS/hooks"

for d in scripts templates themes; do
    [ -d "$REPO/quickshell/$d" ] || { warn "quickshell/$d missing in repo, skipped"; continue; }
    mkdir -p "$QS/$d"
    cp -a "$REPO/quickshell/$d/." "$QS/$d/"
done
cp -f "$REPO/quickshell/shell.qml" "$QS/shell.qml"
chmod +x "$QS"/scripts/*.sh 2>/dev/null || true
echo "  wrote $QS (state/ and wallpapers/ kept)"

# ------------------------------------------------------------ keyboard RGB
say "Installing keyboard color sync"
mkdir -p "$BIN"
KBD=""
for c in \
    "$REPO/wallpaper-keyboard-rgb/scripts/wallpaper-keyboard-rgb-apply" \
    "$REPO/wallpaper-keyboard-rgb/wallpaper-keyboard-rgb-apply"; do
    [ -f "$c" ] && { KBD="$c"; break; }
done
if [ -n "$KBD" ]; then
    install -m 755 "$KBD" "$BIN/wallpaper-keyboard-rgb-apply"
    echo "  wrote $BIN/wallpaper-keyboard-rgb-apply"
    command -v asusctl >/dev/null || warn "asusctl not installed. Keyboard sync needs it (ASUS laptops only)."
else
    warn "No keyboard script in wallpaper-keyboard-rgb/. Skipped."
fi

# ------------------------------------------------------------ Hyprland autostart
say "Writing autostart for the custom panels"
mkdir -p "$HYPR"
cat > "$HYPR/customshell.lua" <<EOF
-- Managed by install.sh. Starts the custom panels at login.
-- Edit the repo copy and re-run install.sh, or change this file directly.
hl.on("hyprland.start", function()
    hl.exec_cmd("quickshell -p $REPO/bar/shell.qml")
    hl.exec_cmd("quickshell -p $REPO/window-tool/shell.qml")
    hl.exec_cmd("quickshell -p $REPO/settings/shell.qml")
end)
EOF
echo "  wrote $HYPR/customshell.lua"

if [ -f "$HYPR/hyprland.lua" ]; then
    if grep -q 'require("customshell")' "$HYPR/hyprland.lua"; then
        echo "  kept  require(\"customshell\") already in hyprland.lua"
    else
        printf '\nrequire("customshell")\n' >> "$HYPR/hyprland.lua"
        echo "  added require(\"customshell\") to hyprland.lua"
    fi
else
    warn "No hyprland.lua found. Add require(\"customshell\") to your Hyprland config yourself."
fi

# ------------------------------------------------------------ kitty
say "Hooking kitty into DMS's theme"
KITTY="$HOME/.config/kitty"
mkdir -p "$KITTY"
touch "$KITTY/kitty.conf"
grep -qxF "include dank-theme.conf" "$KITTY/kitty.conf" || echo "include dank-theme.conf" >> "$KITTY/kitty.conf"

# ------------------------------------------------------------ reload and start
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    say "Reloading Hyprland"
    hyprctl reload >/dev/null 2>&1 || warn "Reload failed. Run 'hyprctl configerrors' to see why."
    hyprctl configerrors 2>/dev/null | grep . && warn "Hyprland reported config errors above."

    say "Starting the custom panels"
    for p in bar window-tool settings; do
        pkill -f "$REPO/$p/shell.qml" 2>/dev/null || true
        setsid quickshell -p "$REPO/$p/shell.qml" >/dev/null 2>&1 < /dev/null &
    done
fi

# ------------------------------------------------------------ done
say "Done"
cat <<MSG
Installed:
  Support files    $QS            (scripts, templates, themes)
  Keyboard sync    $BIN/wallpaper-keyboard-rgb-apply
  Panels           run from $REPO (bar, window-tool, settings)
  Autostart        $HYPR/customshell.lua
Backup:            $BACKUP

Still to do by hand:
  1. Turn off DMS's own bar in its settings, so there is only one bar.
  2. Check your keybinds in $HYPR/dms/binds-user.lua. The installer doesn't write them, so these must exist:
       SUPER+ALT+W  or SUPER+SHIFT+B   wallpaper picker
       SUPER+SHIFT+M                   mirror toggle
       SUPER+P                         display layouts
       SUPER+ALT+S                     settings
  3. Log out and back in once so the video group change applies.

Skipped:
  Airpods-widgets  (not a known format; tell me what it is and I'll add it)
MSG