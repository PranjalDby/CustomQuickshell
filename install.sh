#!/usr/bin/env bash
# Installs the custom Quickshell desktop from this repo onto Arch + Hyprland + DMS.
# Safe to re-run. Backs up what it replaces, and keeps your state, wallpapers, and live Hypr edits.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
QS="$HOME/.config/quickshell"
WT="$HOME/.config/window-tool"
HYPR="$HOME/.config/hypr"
KITTY="$HOME/.config/kitty"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/custom-quickshell-backup-$STAMP"

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Copies a repo file into place only if it doesn't exist yet, so your edits survive
copy_once() {
    local src="$1" dst="$2"
    if [ -e "$dst" ]; then
        echo "  kept  $dst"
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "  made  $dst"
    fi
}

# ------------------------------------------------------------ preflight
[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not root."
command -v pacman >/dev/null || die "pacman not found. This installer is for Arch-based systems."
for d in quickshell window-tool hypr-lua; do
    [ -d "$REPO/$d" ] || die "Missing $REPO/$d"
done

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    warn "Not inside a Hyprland session. Files will be installed, but reload and restart are skipped."
fi

# ------------------------------------------------------------ packages
say "Installing packages"
PKGS=(
    quickshell awww cliphist hypridle hyprlock kitty
    rofi imagemagick jq slurp grim wl-clipboard libnotify wev python
    brightnessctl
    pipewire pipewire-pulse pipewire-alsa wireplumber
    networkmanager bluez bluez-utils
    ttf-jetbrains-mono-nerd
)
sudo pacman -S --needed --noconfirm "${PKGS[@]}" || {
    helper=$(command -v yay || command -v paru || true)
    [ -n "$helper" ] || die "Package install failed. Install quickshell and awww from the AUR, then re-run."
    "$helper" -S --needed --noconfirm "${PKGS[@]}"
}

say "Enabling services"
sudo systemctl enable --now bluetooth.service 2>/dev/null || warn "Could not enable bluetooth.service"
systemctl is-active --quiet NetworkManager || sudo systemctl enable --now NetworkManager.service 2>/dev/null \
    || warn "Could not enable NetworkManager"
sudo usermod -aG video "$USER" 2>/dev/null || warn "Could not add $USER to the video group"

# ------------------------------------------------------------ backup
say "Backing up current configs to $BACKUP"
mkdir -p "$BACKUP"
[ -d "$QS" ]   && cp -a "$QS"   "$BACKUP/quickshell"
[ -d "$WT" ]   && cp -a "$WT"   "$BACKUP/window-tool"
[ -d "$HYPR" ] && cp -a "$HYPR" "$BACKUP/hypr"
[ -d "$KITTY" ] && cp -a "$KITTY" "$BACKUP/kitty"

# ------------------------------------------------------------ quickshell
say "Installing Quickshell config to $QS"
mkdir -p "$QS"
cp -a "$REPO/quickshell/." "$QS/"          # adds and updates files, never deletes yours
mkdir -p "$QS/state" "$QS/wallpapers" "$QS/plugins" "$QS/hooks"
chmod +x "$QS"/scripts/*.sh "$QS"/hooks/*.sh 2>/dev/null || true
echo "  wrote $QS"

# ------------------------------------------------------------ window tool
say "Installing window tool to $WT"
mkdir -p "$WT"
cp -a "$REPO/window-tool/." "$WT/"
echo "  wrote $WT"

# ------------------------------------------------------------ keyboard RGB
say "Installing keyboard RGB sync"
mkdir -p "$BIN"
KBD_SRC=""
for candidate in \
    "$REPO/wallpaper-keyboard-rgb/scripts/wallpaper-keyboard-rgb-apply" \
    "$REPO/wallpaper-keyboard-rgb/wallpaper-keyboard-rgb-apply"; do
    [ -f "$candidate" ] && { KBD_SRC="$candidate"; break; }
done
if [ -n "$KBD_SRC" ]; then
    install -m 755 "$KBD_SRC" "$BIN/wallpaper-keyboard-rgb-apply"
    echo "  wrote $BIN/wallpaper-keyboard-rgb-apply"
    command -v asusctl >/dev/null || warn "asusctl not installed. Keyboard sync needs it (ASUS laptops)."
else
    warn "No keyboard script found in wallpaper-keyboard-rgb/. Skipped."
fi

# ------------------------------------------------------------ Hyprland
say "Installing Hyprland helper files in $HYPR"
mkdir -p "$HYPR"
for f in envs.lua autostart.lua user.lua; do
    if [ -f "$REPO/hypr-lua/$f" ]; then
        copy_once "$REPO/hypr-lua/$f" "$HYPR/$f"
    fi
done

if [ -f "$HYPR/hyprland.lua" ] && ! grep -q 'require("dms.binds")' "$HYPR/hyprland.lua"; then
    warn "hyprland.lua does not load dms.binds. Keep DMS's require lines, then add: require(\"envs\") require(\"autostart\") require(\"user\")"
fi

# ------------------------------------------------------------ kitty
say "Hooking kitty into DMS's theme"
mkdir -p "$KITTY"
touch "$KITTY/kitty.conf"
grep -qxF "include dank-theme.conf" "$KITTY/kitty.conf" || echo "include dank-theme.conf" >> "$KITTY/kitty.conf"

# ------------------------------------------------------------ reload
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    say "Reloading Hyprland"
    hyprctl reload >/dev/null 2>&1 || warn "Reload failed. Run 'hyprctl configerrors' to see why."
    hyprctl configerrors 2>/dev/null | grep . && warn "Hyprland reported config errors above."
fi

say "Done"
cat <<MSG
Installed:
  Quickshell       $QS
  Window tool      $WT
  Keyboard sync    $BIN/wallpaper-keyboard-rgb-apply
Backup:            $BACKUP

Not installed by this script:
  Airpods-widgets  (tell me what it is and I'll add it)
  DMS itself, and its binds in $HYPR/dms/

Add these to autostart, if you want the panels running at login:
  hl.exec_cmd("quickshell -p $QS/shell.qml")
  hl.exec_cmd("quickshell -p $WT/shell.qml")

Log out and back in once so the video group change applies.
MSG