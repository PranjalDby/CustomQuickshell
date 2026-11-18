#!/usr/bin/env bash
#
# librepods-bridge.sh
# -------------------
# Bridge between the DankMaterialShell AirPods plugin and the LibrePods daemon.
#
# LibrePods (https://github.com/kavishdevar/librepods) has no public read API.
# The running daemon publishes what the plugin needs through its system-tray
# StatusNotifierItem and its config file:
#
#   * battery (L / R / case, or a single headset level) -> tray ToolTip
#   * noise mode + conversation awareness               -> tray DBusMenu toggles
#   * device name + ear-detection setting               -> LibrePods config file
#   * connection state                                  -> BlueZ (authoritative)
#
# Control uses the `librepods-ctl` CLI for noise modes. Conversation awareness
# is read-only: LibrePods 0.2.5 has no external way to toggle it.
#
# Usage:
#   librepods-bridge.sh status                  # one line of JSON
#   librepods-bridge.sh noise off|transparency|adaptive|anc
#   librepods-bridge.sh eardetection on|off     # writes LibrePods config
#   librepods-bridge.sh rename <name>           # writes LibrePods config
#
# eardetection and rename take effect when the AirPods next reconnect.
#
# Dependencies: dbus-send (dbus), librepods-ctl (librepods). Bash 4+.

set -uo pipefail

readonly SNI_WATCHER_DEST="org.kde.StatusNotifierWatcher"
readonly SNI_WATCHER_PATH="/StatusNotifierWatcher"
readonly CONF="${XDG_CONFIG_HOME:-$HOME/.config}/AirPodsTrayApp/AirPodsTrayApp.conf"

# Read the config file once per invocation.
CONF_TEXT=""
[[ -f "$CONF" ]] && CONF_TEXT=$(<"$CONF")

# conf_get KEY -> prints the value of KEY in the cached config, or fails.
conf_get() {
    local key="$1" line
    while IFS= read -r line; do
        if [[ "$line" == "$key="* ]]; then
            printf '%s' "${line#*=}"
            return 0
        fi
    done <<<"$CONF_TEXT"
    return 1
}

# conf_set KEY VALUE -> replaces KEY in the config, or appends it.
conf_set() {
    local key="$1" val="$2" esc
    [[ -f "$CONF" ]] || return 1
    if grep -q "^${key}=" "$CONF"; then
        # Escape the characters that are special in the sed replacement.
        esc=${val//\\/\\\\}
        esc=${esc//&/\\&}
        esc=${esc//|/\\|}
        sed -i -E "s|^${key}=.*|${key}=${esc}|" "$CONF"
    else
        printf '%s=%s\n' "$key" "$val" >>"$CONF"
    fi
}

# json_escape STRING -> prints STRING escaped for use inside JSON quotes.
json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

# --- LibrePods tray (StatusNotifierItem) ------------------------------------

# Locate the LibrePods StatusNotifierItem. Prints "SERVICE PATH" or fails.
find_sni() {
    local reply entry service path id
    local -a entries
    reply=$(dbus-send --session --print-reply=literal --dest="$SNI_WATCHER_DEST" \
        "$SNI_WATCHER_PATH" org.freedesktop.DBus.Properties.Get \
        string:"$SNI_WATCHER_DEST" string:RegisteredStatusNotifierItems 2>/dev/null) || return 1

    # Entries look like ":1.89/StatusNotifierItem" or ":1.37/org/ayatana/...".
    mapfile -t entries < <(grep -oE '(:[0-9]+\.[0-9]+|org\.[A-Za-z0-9._-]+)(/[A-Za-z0-9/_-]+)?' <<<"$reply")

    for entry in "${entries[@]}"; do
        if [[ "$entry" == */* ]]; then
            service="${entry%%/*}"
            path="/${entry#*/}"
        else
            service="$entry"
            path="/StatusNotifierItem"
        fi
        # The literal reply ends with the value, so the last field is the id.
        id=$(dbus-send --session --print-reply=literal --dest="$service" "$path" \
            org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierItem string:Id \
            2>/dev/null | awk 'NF{last=$NF} END{print last}')
        if [[ "$id" == "librepods" ]]; then
            printf '%s %s\n' "$service" "$path"
            return 0
        fi
    done
    return 1
}

# read_tooltip SERVICE PATH -> raw ToolTip property.
read_tooltip() {
    dbus-send --session --print-reply --dest="$1" "$2" \
        org.freedesktop.DBus.Properties.Get string:org.kde.StatusNotifierItem string:ToolTip \
        2>/dev/null
}

# read_menu SERVICE -> DBusMenu layout, after asking it to refresh.
read_menu() {
    dbus-send --session --dest="$1" /MenuBar com.canonical.dbusmenu.AboutToShow int32:0 \
        >/dev/null 2>&1
    dbus-send --session --print-reply --dest="$1" /MenuBar \
        com.canonical.dbusmenu.GetLayout int32:0 int32:-1 array:string: 2>/dev/null
}

# --- BlueZ (authoritative connection state) --------------------------------

# bt_connected -> "true" / "false", or fails when the device can't be found.
#
# LibrePods' tray goes stale after the buds return to the case, so BlueZ is the
# source of truth for connection state. Devices are matched by alias: the
# configured deviceName first, then any alias containing "AirPod".
bt_connected() {
    local want objs dev alias conn
    local -a devs
    want=$(conf_get deviceName || true)

    objs=$(dbus-send --system --print-reply --dest=org.bluez / \
        org.freedesktop.DBus.ObjectManager.GetManagedObjects 2>/dev/null) || return 1

    # Device object paths end in a quote in the reply, which excludes the
    # /sepN and /fdN child objects.
    mapfile -t devs < <(grep -oE '/org/bluez/hci[0-9]+/dev_[0-9A-F_]+"' <<<"$objs" \
        | tr -d '"' | sort -u)

    for dev in "${devs[@]}"; do
        alias=$(dbus-send --system --print-reply=literal --dest=org.bluez "$dev" \
            org.freedesktop.DBus.Properties.Get string:org.bluez.Device1 string:Alias \
            2>/dev/null | tail -1 | sed -E 's/^[[:space:]]*variant[[:space:]]+string[[:space:]]+//')

        if { [[ -n "$want" && "$alias" == "$want" ]] || [[ "$alias" == *AirPod* ]]; }; then
            conn=$(dbus-send --system --print-reply=literal --dest=org.bluez "$dev" \
                org.freedesktop.DBus.Properties.Get string:org.bluez.Device1 string:Connected \
                2>/dev/null | tail -1 | awk '{print $NF}')
            if [[ "$conn" == "true" || "$conn" == "false" ]]; then
                printf '%s\n' "$conn"
                return 0
            fi
        fi
    done
    return 1
}

# --- commands --------------------------------------------------------------

cmd_status() {
    local service="" path="" sni tooltip="" menu="" t label="" state=""
    local connected=false model="buds" mode="unknown" conversation=false
    local left=-1 right=-1 caseLvl=-1 headset=-1
    local ed_setting name eardetection=false bt
    local -a lines

    bt=$(bt_connected) || bt=""

    if sni=$(find_sni); then
        read -r service path <<<"$sni"
        tooltip=$(read_tooltip "$service" "$path")
        menu=$(read_menu "$service")
    fi

    # Battery from the tooltip, e.g. "Battery Status: Left: 82%, Right: 79%, Case: 100%".
    t="${tooltip,,}"
    if [[ $t =~ headset:[[:space:]]*([0-9]+) ]]; then
        model="headset"
        headset=${BASH_REMATCH[1]}
        connected=true
    elif [[ $t =~ left:[[:space:]]*([0-9]+) ]]; then
        left=${BASH_REMATCH[1]}
        [[ $t =~ right:[[:space:]]*([0-9]+) ]] && right=${BASH_REMATCH[1]}
        [[ $t =~ case:[[:space:]]*([0-9]+) ]] && caseLvl=${BASH_REMATCH[1]}
        connected=true
    fi

    # Noise mode and conversation awareness from the DBusMenu toggle states.
    if [[ -n "$menu" ]]; then
        while IFS= read -r line; do
            if [[ $line == LABEL:* ]]; then
                label=${line#LABEL:}
            elif [[ $line == STATE:* ]]; then
                state=${line#STATE:}
                [[ "$state" == 1 ]] || continue
                case "$label" in
                    "Off")                              mode="off" ;;
                    "Transparency")                     mode="transparency" ;;
                    "Adaptive")                         mode="adaptive" ;;
                    "Noise Cancellation")               mode="anc" ;;
                    "Toggle Conversational Awareness")  conversation=true ;;
                esac
            fi
        done < <(grep -oE 'string "[^"]+"|int32 [0-9]+' <<<"$menu" | awk '
            /^string "label"/        { next }
            /^string "toggle-state"/ { expect_state=1; next }
            /^string "/              { gsub(/^string "|"$/, ""); print "LABEL:" $0; next }
            /^int32/                 { if (expect_state) { print "STATE:" $2; expect_state=0 } }
        ')
        # A menu means LibrePods is running and the device is present.
        [[ "$mode" != "unknown" ]] && connected=true
    fi

    # Device name and ear-detection setting from the config file.
    name=$(conf_get deviceName || true)
    [[ -z "$name" ]] && name="AirPods"
    ed_setting=$(conf_get setting || true)
    # setting >= 1 means ear detection is on.
    if [[ "${ed_setting:-0}" =~ ^[0-9]+$ ]] && (( ed_setting >= 1 )); then
        eardetection=true
    fi

    # BlueZ has the final say. When it reports a disconnect, clear the readouts
    # so stale tray values are not shown.
    case "$bt" in
        true)  connected=true ;;
        false)
            connected=false; model="buds"
            left=-1; right=-1; caseLvl=-1; headset=-1
            mode="unknown"; conversation=false
            ;;
    esac

    printf '{"connected":%s,"model":"%s","left":%s,"right":%s,"case":%s,"headset":%s,"mode":"%s","conversation":%s,"earDetection":%s,"deviceName":"%s"}\n' \
        "$connected" "$model" "$left" "$right" "$caseLvl" "$headset" \
        "$mode" "$conversation" "$eardetection" "$(json_escape "$name")"
}

cmd_noise() {
    case "${1:-}" in
        off|transparency|adaptive|anc) exec librepods-ctl "noise:${1}" ;;
        *) echo "unknown noise mode: ${1:-}" >&2; exit 2 ;;
    esac
}

cmd_eardetection() {
    case "${1:-}" in
        on)  conf_set setting 1 ;;
        off) conf_set setting 0 ;;
        *)   echo "usage: $0 eardetection on|off" >&2; exit 2 ;;
    esac
}

cmd_rename() {
    local name="$*"
    [[ -z "$name" ]] && { echo "usage: $0 rename <name>" >&2; exit 2; }
    conf_set deviceName "$name"
}

# --- dispatch --------------------------------------------------------------

case "${1:-status}" in
    status)       cmd_status ;;
    noise)        cmd_noise "${2:-}" ;;
    eardetection) cmd_eardetection "${2:-}" ;;
    rename)       shift; cmd_rename "$@" ;;
    *)            echo "usage: $0 {status|noise <mode>|eardetection on|off|rename <name>}" >&2; exit 2 ;;
esac
