#!/usr/bin/env bash
# Quickshell + Hyprland setup using Lua config files.
# Copies working Lua modules from hypr-lua/ in the repo. Safe to re-run.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/quickshell"
LUA_SRC="$HERE/hypr-lua"
QS="$HOME/.config/quickshell"
HYPR="$HOME/.config/hypr"
KITTY="$HOME/.config/kitty"
ME="${USER:-$(whoami)}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config/setup-desktop-backup-$STAMP"

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

write_managed() {   # always overwritten
    mkdir -p "$(dirname "$1")"
    cat > "$1"
    echo "  wrote $1"
}

copy_managed() {    # always overwritten from the repo
    [ -f "$LUA_SRC/$1" ] || die "Missing $LUA_SRC/$1. See Step 1 in the setup notes."
    cp -f "$LUA_SRC/$1" "$HYPR/$1"
    echo "  wrote $HYPR/$1"
}

copy_once() {       # copied only if missing, so your edits stay
    [ -f "$LUA_SRC/$1" ] || die "Missing $LUA_SRC/$1. See Step 1 in the setup notes."
    if [ -e "$HYPR/$1" ]; then
        echo "  kept  $HYPR/$1 (yours)"
    else
        cp "$LUA_SRC/$1" "$HYPR/$1"
        echo "  made  $HYPR/$1"
    fi
}

# ------------------------------------------------------------------ preflight
[ "$(id -u)" -ne 0 ] || die "Run as your normal user, not root."
[ -d "$SRC" ] || die "quickshell/ folder not found next to this script ($SRC)."
[ -d "$LUA_SRC" ] || die "hypr-lua/ folder not found. Complete Step 1 first."
[ -f "$SRC/templates/theme.lua.tmpl" ] || die "Missing quickshell/templates/theme.lua.tmpl. Complete Step 1 first."
command -v pacman >/dev/null || die "pacman not found. This script is for Arch-based systems."

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    warn "Not inside a Hyprland session. Files will be written, but live reload is skipped."
fi

# ------------------------------------------------------------------ packages
say "Installing packages"
PKGS=(
    hyprland quickshell hypridle hyprlock swww cliphist
    wl-clipboard grim slurp libnotify brightnessctl
    pipewire pipewire-pulse pipewire-alsa wireplumber
    networkmanager bluez bluez-utils
    kitty ttf-jetbrains-mono-nerd
)
sudo pacman -S --needed --noconfirm "${PKGS[@]}" || {
    helper=$(command -v yay || command -v paru || true)
    [ -n "$helper" ] || die "Install failed. Install quickshell from the AUR (yay -S quickshell), then re-run."
    "$helper" -S --needed --noconfirm "${PKGS[@]}"
}

# ------------------------------------------------------------------ services and permissions
say "Enabling services and permissions"

sudo systemctl enable --now bluetooth.service || warn "Could not enable bluetooth.service"

if ! systemctl is-active --quiet NetworkManager; then
    if systemctl is-active --quiet iwd || systemctl is-active --quiet systemd-networkd; then
        warn "iwd or systemd-networkd is active. The Wi-Fi panel needs NetworkManager."
        warn "Switch manually if you're sure: sudo systemctl disable --now iwd && sudo systemctl enable --now NetworkManager"
    else
        sudo systemctl enable --now NetworkManager.service || warn "Could not enable NetworkManager"
    fi
fi

sudo usermod -aG video "$ME" || warn "Could not add $ME to the video group (brightness keys need it)"

systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null \
    || warn "Could not start PipeWire user services. Log out and back in, then re-run."

# ------------------------------------------------------------------ backup
say "Backing up current configs to $BACKUP"
mkdir -p "$BACKUP"
[ -d "$HYPR" ]  && cp -r "$HYPR"  "$BACKUP/hypr"
[ -d "$QS" ]    && cp -r "$QS"    "$BACKUP/quickshell"
[ -d "$KITTY" ] && cp -r "$KITTY" "$BACKUP/kitty"

# ------------------------------------------------------------------ quickshell files
say "Installing Quickshell config"
if [ -d "$QS/state" ]; then
    cp -r "$QS/state" "$BACKUP/state-keep"
fi
rm -rf "$QS"
mkdir -p "$(dirname "$QS")"
cp -r "$SRC" "$QS"
if [ -d "$BACKUP/state-keep" ]; then
    cp -r "$BACKUP/state-keep" "$QS/state"
fi
mkdir -p "$QS/wallpapers" "$QS/plugins" "$QS/state"
chmod +x "$QS/scripts/"*.sh 2>/dev/null || true

# ------------------------------------------------------------------ hyprland (Lua)
say "Writing Hyprland Lua config in $HYPR"
mkdir -p "$HYPR"

# Remove the old .conf modules so Hyprland only sees the Lua files.
# hypridle.conf and hyprlock.conf belong to other programs and are kept.
for f in hyprland envs monitors input looknfeel autostart bindings user; do
    rm -f "$HYPR/$f.conf"
done

copy_managed hyprland.lua
copy_managed envs.lua
copy_managed autostart.lua
copy_managed bindings.lua

# Your settings: copied the first time, then kept
copy_once monitors.lua
copy_once input.lua
copy_once looknfeel.lua
copy_once user.lua

# theme.lua is generated from the template by apply-theme.sh
[ -s "$HYPR/theme.lua" ] || echo '-- generated by apply-theme.sh' > "$HYPR/theme.lua"

# ------------------------------------------------------------------ hypridle (not part of Hyprland)
say "Writing hypridle config"
write_managed "$HYPR/hypridle.conf" <<'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = loginctl lock-session
}

listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
EOF

# ------------------------------------------------------------------ kitty
say "Hooking kitty into the theme"
mkdir -p "$KITTY"
touch "$KITTY/kitty.conf"
grep -qxF "include theme.conf" "$KITTY/kitty.conf" || echo "include theme.conf" >> "$KITTY/kitty.conf"

# ------------------------------------------------------------------ apply theme
say "Applying your current theme"
current=$(cat "$QS/state/theme" 2>/dev/null || echo tokyo-night)
[ -f "$QS/themes/$current.env" ] || current=tokyo-night
"$QS/scripts/apply-theme.sh" "$current" || warn "Theme apply reported an error"

# ------------------------------------------------------------------ restart
say "Restarting services"
pkill -x waybar 2>/dev/null || true
pkill -x mako 2>/dev/null || true
pkill -x hypridle 2>/dev/null || true
pkill -x quickshell 2>/dev/null || true

if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    hyprctl reload >/dev/null 2>&1 || warn "Could not reload Hyprland. Run 'hyprctl reload' later."
    hyprctl configerrors 2>/dev/null | head -5 | grep . && warn "Hyprland reported config errors above."
fi

setsid quickshell >/dev/null 2>&1 < /dev/null &
setsid hypridle >/dev/null 2>&1 < /dev/null &
pgrep -x swww-daemon >/dev/null || { setsid swww-daemon >/dev/null 2>&1 < /dev/null & }
pgrep -f "cliphist store" >/dev/null || {
    setsid sh -c 'wl-paste --type text --watch cliphist store' >/dev/null 2>&1 < /dev/null &
    setsid sh -c 'wl-paste --type image --watch cliphist store' >/dev/null 2>&1 < /dev/null &
}

say "Done"
cat <<MSG
Hyprland Lua config: $HYPR
Quickshell config:   $QS
Backup:              $BACKUP

Edit these yourself (kept between runs):
  monitors.lua, input.lua, looknfeel.lua, user.lua
Managed (overwritten on each run, edit the repo copy in hypr-lua/):
  hyprland.lua, envs.lua, autostart.lua, bindings.lua

Log out and back in once so the video group change applies.
MSG