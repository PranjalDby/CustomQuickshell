#!/usr/bin/env bash
# Quickshell desktop installer for Omarchy (Hyprland)
# Usage: ./install.sh
set -euo pipefail

QS="$HOME/.config/quickshell"
HYPR="$HOME/.config/hypr"
KITTY="$HOME/.config/kitty"
STAMP="$(date +%Y%m%d-%H%M%S)"

say()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

write_file() {
    mkdir -p "$(dirname "$1")"
    cat > "$1"
}

[ "$(id -u)" -ne 0 ] || die "Run this as your normal user, not root."
command -v pacman >/dev/null || die "pacman not found. This installer is for Arch-based systems (Omarchy)."

# ---------------------------------------------------------------- packages
say "Installing packages"
PKGS=(quickshell brightnessctl networkmanager wireplumber grim slurp wl-clipboard libnotify ttf-jetbrains-mono-nerd)
sudo pacman -S --needed --noconfirm "${PKGS[@]}" || {
    helper=$(command -v yay || command -v paru || true)
    [ -n "$helper" ] || die "Package install failed. Install quickshell from the AUR (yay -S quickshell), then rerun."
    "$helper" -S --needed --noconfirm "${PKGS[@]}"
}

# ---------------------------------------------------------------- backup
say "Backing up existing configs"
if [ -d "$QS" ]; then
    mv "$QS" "$QS-backup-$STAMP"
    echo "Old quickshell config moved to $QS-backup-$STAMP"
fi
for f in "$HYPR/hyprland.conf" "$KITTY/kitty.conf"; do
    [ -f "$f" ] && cp "$f" "$f.bak-$STAMP" && echo "Backed up $f"
done

# ---------------------------------------------------------------- shell files
say "Writing shell files"

write_file "$QS/shell.qml" <<'EOF'
import Quickshell
import Quickshell.Io
import QtQuick
import "modules"

ShellRoot {
    Bar {
        id: bar
        onLauncherRequested: launcher.visible = !launcher.visible
        onMenuRequested: menu.toggle()
    }

    Launcher { id: launcher }
    Osd { id: osd }
    Notifications { }

    ThemeSelector { id: themes }
    Display { id: display }

    Menu {
        id: menu
        onThemeRequested: themes.open()
        onDisplayRequested: display.visible = true
    }

    Connections {
        target: System
        function onOsdRequested(kind, value) { osd.show(kind, value) }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible = !launcher.visible }
    }

    IpcHandler {
        target: "menu"
        function toggle(): void { menu.toggle() }
    }

    IpcHandler {
        target: "themes"
        function open(): void { themes.open() }
        function next(): void {
            const i = Theme.names.indexOf(Theme.name)
            Theme.setTheme(Theme.names[(i + 1) % Theme.names.length])
        }
        function set(name: string): void { Theme.setTheme(name) }
    }

    IpcHandler {
        target: "display"
        function toggle(): void { display.toggle() }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { System.setBrightness("5%+") }
        function down(): void { System.setBrightness("5%-") }
    }

    IpcHandler {
        target: "volume"
        function up(): void { System.setVolume("5%+") }
        function down(): void { System.setVolume("5%-") }
        function mute(): void { System.toggleMute() }
    }
}
EOF

write_file "$QS/modules/qmldir" <<'EOF'
singleton Theme 1.0 Theme.qml
singleton System 1.0 System.qml
Pill 1.0 Pill.qml
Bar 1.0 Bar.qml
Launcher 1.0 Launcher.qml
Menu 1.0 Menu.qml
Notifications 1.0 Notifications.qml
Osd 1.0 Osd.qml
ThemeSelector 1.0 ThemeSelector.qml
Display 1.0 Display.qml
EOF

write_file "$QS/modules/Theme.qml" <<'EOF'
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string qsDir: Quickshell.env("HOME") + "/.config/quickshell"

    property var names: []
    property var all: ({})
    property string name: "tokyo-night"
    property bool previewing: false

    readonly property var fallback: ({
        bg: "#1a1b26", surface: "#24283b", fg: "#c0caf5", muted: "#565f89",
        accent: "#7aa2f7", red: "#f7768e", green: "#9ece6a", yellow: "#e0af68"
    })

    property var committed: fallback
    property var c: fallback

    readonly property color bg: c.bg
    readonly property color surface: c.surface
    readonly property color fg: c.fg
    readonly property color muted: c.muted
    readonly property color accent: c.accent
    readonly property color red: c.red
    readonly property color green: c.green
    readonly property color yellow: c.yellow

    readonly property int radius: 8
    readonly property string font: "JetBrainsMono Nerd Font"

    function parseEnv(text) {
        const out = {}
        text.split("\n").forEach(line => {
            const i = line.indexOf("=")
            if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim()
        })
        return out
    }

    function setTheme(n) {
        if (names.indexOf(n) < 0) return
        name = n
        previewing = false
        if (all[n]) {
            committed = Object.assign({}, fallback, all[n])
            c = committed
        }
        applier.command = [root.qsDir + "/scripts/apply-theme.sh", n]
        applier.running = true
    }

    function preview(n) {
        if (!all[n]) return
        previewing = true
        c = Object.assign({}, fallback, all[n])
    }

    function cancelPreview() {
        previewing = false
        c = committed
    }

    Process {
        id: loader
        command: ["sh", "-c",
            "for f in \"$1\"/*.env; do [ -f \"$f\" ] || continue; echo \"@@ $(basename \"$f\" .env)\"; cat \"$f\"; echo; done",
            "sh", root.qsDir + "/themes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                this.text.split("@@ ").slice(1).forEach(part => {
                    const nl = part.indexOf("\n")
                    if (nl < 0) return
                    map[part.slice(0, nl).trim()] = root.parseEnv(part.slice(nl + 1))
                })
                root.all = map
                root.names = Object.keys(map).sort()
            }
        }
    }

    Process { id: applier }

    FileView {
        id: colorsFile
        path: root.qsDir + "/state/colors.env"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.committed = Object.assign({}, root.fallback, root.parseEnv(text()))
            if (!root.previewing) root.c = root.committed
        }
    }

    FileView {
        id: themeFile
        path: root.qsDir + "/state/theme"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.name = text().trim()
    }

    Component.onCompleted: loader.running = true
}
EOF

write_file "$QS/modules/System.qml" <<'EOF'
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int brightness: 0
    property int volume: 0
    property bool muted: false

    signal osdRequested(string kind, int value)

    function setBrightness(arg) {
        brightSet.command = ["sh", "-c",
            "brightnessctl -q set \"$1\"; brightnessctl -m | cut -d, -f4 | tr -d %", "sh", arg]
        brightSet.running = true
    }

    function setVolume(arg) {
        volSet.command = ["sh", "-c",
            "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ \"$1\"; wpctl get-volume @DEFAULT_AUDIO_SINK@", "sh", arg]
        volSet.running = true
    }

    function toggleMute() {
        volSet.command = ["sh", "-c",
            "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        volSet.running = true
    }

    function readVolume(t) {
        const m = t.match(/([\d.]+)/)
        if (m) root.volume = Math.round(parseFloat(m[1]) * 100)
        root.muted = t.includes("MUTED")
    }

    function refresh() {
        brightRead.running = true
        volRead.running = true
    }

    Process {
        id: brightSet
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text)
                if (!isNaN(v)) {
                    root.brightness = v
                    root.osdRequested("Brightness", v)
                }
            }
        }
    }

    Process {
        id: volSet
        stdout: StdioCollector {
            onStreamFinished: {
                root.readVolume(this.text)
                root.osdRequested(root.muted ? "Muted" : "Volume", root.volume)
            }
        }
    }

    Process {
        id: brightRead
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text)
                if (!isNaN(v)) root.brightness = v
            }
        }
    }

    Process {
        id: volRead
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: root.readVolume(this.text)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
EOF

write_file "$QS/modules/Pill.qml" <<'EOF'
import QtQuick

Rectangle {
    id: pill

    property alias text: label.text
    property bool highlighted: false
    signal clicked()

    implicitWidth: label.implicitWidth + 16
    height: 24
    radius: Theme.radius
    color: highlighted ? Theme.accent : Theme.surface

    Text {
        id: label
        anchors.centerIn: parent
        color: pill.highlighted ? Theme.bg : Theme.fg
        font.family: Theme.font
        font.pixelSize: 12
    }

    MouseArea {
        anchors.fill: parent
        onClicked: pill.clicked()
    }
}
EOF

write_file "$QS/modules/Bar.qml" <<'EOF'
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: bar

    signal launcherRequested()
    signal menuRequested()

    anchors { top: true; left: true; right: true }
    implicitHeight: 36
    color: Theme.bg

    property int battery: -1
    property string network: "offline"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true
            batFile.reload()
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: bar.network = this.text.trim() || "offline"
        }
    }

    FileView {
        id: batFile
        path: "/sys/class/power_supply/BAT0/capacity"
        onLoaded: bar.battery = parseInt(text())
        onLoadFailed: bar.battery = -1
    }

    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        Repeater {
            model: Hyprland.workspaces

            Pill {
                required property var modelData
                text: modelData.name
                highlighted: modelData.active
                onClicked: modelData.activate()
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 420)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: Hyprland.activeToplevel?.title ?? ""
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 13
    }

    Row {
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        Pill {
            text: bar.network
            onClicked: netProc.running = true
        }

        Pill {
            text: System.muted ? "muted" : "vol " + System.volume + "%"
            onClicked: System.toggleMute()
        }

        Pill {
            visible: bar.battery >= 0
            text: "bat " + bar.battery + "%"
        }

        Pill {
            text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
        }

        Pill {
            text: "Apps"
            highlighted: true
            onClicked: bar.launcherRequested()
        }

        Pill {
            text: "Menu"
            onClicked: bar.menuRequested()
        }
    }
}
EOF

write_file "$QS/modules/Launcher.qml" <<'EOF'
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: launcher

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#99000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""

    readonly property var results: {
        const q = query.toLowerCase()
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay && a.name.toLowerCase().includes(q))
            .slice(0, 40)
    }

    onVisibleChanged: {
        if (visible) {
            input.text = ""
            input.forceActiveFocus()
        }
    }

    function launch(entry) {
        entry.execute()
        launcher.visible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: launcher.visible = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        width: 520
        height: 440
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.accent

        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            TextInput {
                id: input
                width: parent.width
                focus: true
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 16
                onTextChanged: {
                    launcher.query = text
                    list.currentIndex = 0
                }
                Keys.onEscapePressed: launcher.visible = false
                Keys.onReturnPressed: {
                    if (launcher.results.length > 0) launcher.launch(launcher.results[list.currentIndex])
                }
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - input.height - 8
                clip: true
                model: launcher.results

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 36
                    radius: 6
                    color: list.currentIndex === index ? Theme.accent : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: modelData.name
                        color: list.currentIndex === index ? Theme.bg : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: launcher.launch(modelData)
                    }
                }
            }
        }
    }
}
EOF

write_file "$QS/modules/Osd.qml" <<'EOF'
import Quickshell
import QtQuick

PanelWindow {
    id: osd

    visible: false
    anchors { bottom: true }
    margins { bottom: 80 }
    implicitWidth: 320
    implicitHeight: 56
    color: "transparent"

    property string label: ""
    property int value: 0

    function show(kind, v) {
        label = kind
        value = v
        visible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.accent

        Column {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            Text {
                text: osd.label + "  " + osd.value + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: Theme.surface

                Rectangle {
                    width: parent.width * Math.min(osd.value, 100) / 100
                    height: parent.height
                    radius: 4
                    color: Theme.accent
                }
            }
        }
    }
}
EOF

write_file "$QS/modules/Notifications.qml" <<'EOF'
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property int counter: 0
    ListModel { id: items }

    NotificationServer {
        id: server
        bodySupported: true
        onNotification: notification => {
            notification.tracked = true
            root.counter += 1
            items.insert(0, {
                uid: root.counter,
                summary: notification.summary,
                body: notification.body,
                app: notification.appName
            })
            if (items.count > 5) items.remove(5)
        }
    }

    function remove(uid) {
        for (let i = 0; i < items.count; i++) {
            if (items.get(i).uid === uid) {
                items.remove(i)
                return
            }
        }
    }

    PanelWindow {
        visible: items.count > 0
        anchors { top: true; right: true }
        margins { top: 44; right: 8 }
        implicitWidth: 320
        implicitHeight: col.implicitHeight
        color: "transparent"

        Column {
            id: col
            width: parent.width
            spacing: 8

            Repeater {
                model: items

                delegate: Rectangle {
                    required property int uid
                    required property string summary
                    required property string body
                    required property string app

                    width: 320
                    height: content.implicitHeight + 16
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.accent

                    Column {
                        id: content
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 4

                        Text {
                            text: app
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                        Text {
                            width: parent.width
                            text: summary
                            color: Theme.fg
                            font.family: Theme.font
                            font.bold: true
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: body.length > 0
                            text: body
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.remove(uid)
                    }

                    Timer {
                        interval: 6000
                        running: true
                        onTriggered: root.remove(uid)
                    }
                }
            }
        }
    }
}
EOF

write_file "$QS/modules/ThemeSelector.qml" <<'EOF'
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: selector

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function open() {
        list.currentIndex = Math.max(0, Theme.names.indexOf(Theme.name))
        visible = true
    }

    function close(apply) {
        if (apply && Theme.names.length > 0) Theme.setTheme(Theme.names[list.currentIndex])
        else Theme.cancelPreview()
        visible = false
    }

    function move(delta) {
        const n = Theme.names.length
        if (n === 0) return
        list.currentIndex = (list.currentIndex + delta + n) % n
        Theme.preview(Theme.names[list.currentIndex])
    }

    onVisibleChanged: if (visible) scope.forceActiveFocus()

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: selector.close(false)
        Keys.onReturnPressed: selector.close(true)
        Keys.onEnterPressed: selector.close(true)
        Keys.onUpPressed: selector.move(-1)
        Keys.onDownPressed: selector.move(1)

        MouseArea {
            anchors.fill: parent
            onClicked: selector.close(false)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 460
            height: 520
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: column
                anchors { fill: parent; margins: 14 }
                spacing: 10

                Text {
                    id: header
                    text: "THEMES   ↑↓ preview   Enter apply   Esc cancel"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                ListView {
                    id: list
                    width: parent.width
                    height: column.height - header.height - column.spacing
                    clip: true
                    model: Theme.names

                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property var col: Theme.all[modelData] || ({})

                        width: list.width
                        height: 44
                        radius: 6
                        color: list.currentIndex === index ? Theme.surface : "transparent"
                        border.color: modelData === Theme.name ? Theme.accent : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: modelData + (modelData === Theme.name ? "  (current)" : "")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        Row {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 4

                            Repeater {
                                model: ["bg", "accent", "red", "green", "yellow", "fg"]

                                Rectangle {
                                    required property string modelData
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: col[modelData] || "#000000"
                                    border.color: Theme.muted
                                    border.width: 1
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                list.currentIndex = index
                                selector.close(true)
                            }
                        }
                    }
                }
            }
        }
    }
}
EOF

write_file "$QS/modules/Display.qml" <<'EOF'
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: display

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var monitors: Hyprland.monitors.values
    readonly property var source: monitors.length > 0 ? monitors[0] : null

    function toggle() { visible = !visible }

    function run(cmd) {
        runner.command = ["sh", "-c", cmd]
        runner.running = true
    }

    function mirror(m) {
        if (!source || m.name === source.name) return
        run("hyprctl keyword monitor \"" + m.name + ",preferred,auto," + (m.scale || 1)
            + ",mirror," + source.name + "\"")
    }

    function extend(m) {
        run("hyprctl keyword monitor \"" + m.name + ",preferred,auto," + (m.scale || 1) + "\"")
    }

    function extendAll() {
        const cmds = monitors.map(m => "hyprctl keyword monitor \"" + m.name + ",preferred,auto," + (m.scale || 1) + "\"")
        run(cmds.join("; "))
    }

    Process { id: runner }

    onVisibleChanged: if (visible) scope.forceActiveFocus()

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: display.visible = false

        MouseArea {
            anchors.fill: parent
            onClicked: display.visible = false
        }

        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 44; rightMargin: 8 }
            width: 360
            height: body.implicitHeight + 28
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 12

                Text {
                    text: "DISPLAYS"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Text {
                    width: parent.width
                    text: display.monitors.length < 2
                        ? "Connect a second monitor to use mirror mode."
                        : "Mirror shows the source screen on the other display. Extend gives each display its own desktop."
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model: display.monitors

                    Column {
                        required property var modelData
                        required property int index
                        width: body.width
                        spacing: 6

                        Text {
                            text: modelData.name + (index === 0 ? "   (source)" : "")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Row {
                            spacing: 6

                            Pill {
                                visible: index > 0
                                text: "Mirror " + (display.source ? display.source.name : "")
                                highlighted: true
                                onClicked: display.mirror(modelData)
                            }

                            Pill {
                                text: "Extend"
                                onClicked: display.extend(modelData)
                            }
                        }
                    }
                }

                Pill {
                    visible: display.monitors.length > 1
                    text: "Extend all"
                    onClicked: display.extendAll()
                }
            }
        }
    }
}
EOF

write_file "$QS/modules/Menu.qml" <<'EOF'
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: menu

    signal themeRequested()
    signal displayRequested()

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string pending: ""

    function toggle() { visible = !visible }

    function run(cmd, delayMs) {
        pending = cmd
        visible = false
        runTimer.interval = delayMs || 0
        runTimer.restart()
    }

    onVisibleChanged: if (visible) scope.forceActiveFocus()

    Timer {
        id: runTimer
        onTriggered: {
            runner.command = ["sh", "-c", menu.pending]
            runner.running = true
        }
    }

    Process { id: runner }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: menu.visible = false

        MouseArea {
            anchors.fill: parent
            onClicked: menu.visible = false
        }

        Rectangle {
            id: card
            anchors { top: parent.top; right: parent.right; topMargin: 44; rightMargin: 8 }
            width: 300
            height: body.implicitHeight + 24
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                Text { text: "APPEARANCE"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Row {
                    spacing: 6
                    Pill {
                        text: "Themes"
                        highlighted: true
                        onClicked: { menu.visible = false; menu.themeRequested() }
                    }
                    Pill {
                        text: "Displays"
                        onClicked: { menu.visible = false; menu.displayRequested() }
                    }
                }

                Text { text: "AUDIO"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Row {
                    spacing: 6
                    Pill { text: "Vol -"; onClicked: System.setVolume("5%-") }
                    Pill { text: "Vol +"; onClicked: System.setVolume("5%+") }
                    Pill { text: System.muted ? "Unmute" : "Mute"; onClicked: System.toggleMute() }
                }

                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: Theme.surface
                    Rectangle {
                        width: parent.width * Math.min(System.volume, 100) / 100
                        height: parent.height
                        radius: 4
                        color: System.muted ? Theme.muted : Theme.accent
                    }
                }

                Text { text: "DISPLAY"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Row {
                    spacing: 6
                    Pill { text: "Bright -"; onClicked: System.setBrightness("5%-") }
                    Pill { text: "Bright +"; onClicked: System.setBrightness("5%+") }
                }

                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: Theme.surface
                    visible: System.brightness > 0
                    Rectangle {
                        width: parent.width * Math.min(System.brightness, 100) / 100
                        height: parent.height
                        radius: 4
                        color: Theme.accent
                    }
                }

                Text { text: "SYSTEM"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Flow {
                    width: parent.width
                    spacing: 6
                    Pill { text: "Lock"; onClicked: menu.run("hyprlock") }
                    Pill { text: "Screenshot"; onClicked: menu.run("~/.config/quickshell/scripts/screenshot.sh", 300) }
                    Pill { text: "Logout"; onClicked: menu.run("hyprctl dispatch exit") }
                }
            }
        }
    }
}
EOF

# ---------------------------------------------------------------- themes
say "Writing themes"

theme() { # name bg surface fg muted accent red green yellow
    write_file "$QS/themes/$1.env" <<EOF
bg=$2
surface=$3
fg=$4
muted=$5
accent=$6
red=$7
green=$8
yellow=$9
EOF
}

theme tokyo-night  "#1a1b26" "#24283b" "#c0caf5" "#565f89" "#7aa2f7" "#f7768e" "#9ece6a" "#e0af68"
theme catppuccin   "#1e1e2e" "#313244" "#cdd6f4" "#6c7086" "#89b4fa" "#f38ba8" "#a6e3a1" "#f9e2af"
theme gruvbox      "#282828" "#3c3836" "#ebdbb2" "#928374" "#83a598" "#fb4934" "#b8bb26" "#fabd2f"
theme nord         "#2e3440" "#3b4252" "#eceff4" "#4c566a" "#88c0d0" "#bf616a" "#a3be8c" "#ebcb8b"
theme rose-pine    "#191724" "#26233a" "#e0def4" "#6e6a86" "#c4a7e7" "#eb6f92" "#9ccfd8" "#f6c177"
theme everforest   "#2d353b" "#343f44" "#d3c6aa" "#859289" "#7fbbb3" "#e67e80" "#a7c080" "#dbbc7f"
theme kanagawa     "#1f1f28" "#2a2a37" "#dcd7ba" "#727169" "#7e9cd8" "#c34043" "#98bb6c" "#e6c384"

# ---------------------------------------------------------------- scripts & templates
say "Writing scripts and templates"

write_file "$QS/scripts/apply-theme.sh" <<'EOF'
#!/bin/sh
# Usage: apply-theme.sh <theme-name>
QS="$HOME/.config/quickshell"
name="$1"
src="$QS/themes/$name.env"

[ -f "$src" ] || { echo "No theme named $name" >&2; exit 1; }

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

render "$QS/templates/hyprland.tmpl" "$HOME/.config/hypr/theme.conf"
render "$QS/templates/kitty.tmpl" "$HOME/.config/kitty/theme.conf"

hyprctl reload >/dev/null 2>&1
pkill -USR1 -x kitty 2>/dev/null
exit 0
EOF

write_file "$QS/scripts/screenshot.sh" <<'EOF'
#!/bin/sh
dir="$HOME/Pictures/Screenshots"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
mkdir -p "$dir"

region=$(slurp -d) || exit 0
grim -g "$region" "$file" && wl-copy < "$file" && notify-send "Screenshot saved" "$file"
EOF

write_file "$QS/templates/hyprland.tmpl" <<'EOF'
general {
    col.active_border = rgb({{accent_raw}})
    col.inactive_border = rgb({{surface_raw}})
}
EOF

write_file "$QS/templates/kitty.tmpl" <<'EOF'
background {{bg}}
foreground {{fg}}
cursor {{accent}}
selection_background {{surface}}
selection_foreground {{fg}}
color1 {{red}}
color2 {{green}}
color3 {{yellow}}
color4 {{accent}}
color8 {{muted}}
EOF

chmod +x "$QS/scripts/"*.sh

# ---------------------------------------------------------------- hyprland & kitty config
say "Configuring Hyprland and kitty"

mkdir -p "$HYPR" "$KITTY"
touch "$HYPR/hyprland.conf" "$KITTY/kitty.conf"

# Remove any previous quickshell block, then add a fresh one
sed -i '/# >>> quickshell >>>/,/# <<< quickshell <<</d' "$HYPR/hyprland.conf"
cat >> "$HYPR/hyprland.conf" <<'EOF'

# >>> quickshell >>>
source = ~/.config/hypr/theme.conf
exec-once = quickshell

bind = SUPER, Space, exec, qs ipc call launcher toggle
bind = SUPER, M, exec, qs ipc call menu toggle
bind = SUPER, T, exec, qs ipc call themes open
bind = SUPER SHIFT, T, exec, qs ipc call themes next
bind = SUPER, D, exec, qs ipc call display toggle
bind = , Print, exec, ~/.config/quickshell/scripts/screenshot.sh
bind = , XF86MonBrightnessUp, exec, qs ipc call brightness up
bind = , XF86MonBrightnessDown, exec, qs ipc call brightness down
bind = , XF86AudioRaiseVolume, exec, qs ipc call volume up
bind = , XF86AudioLowerVolume, exec, qs ipc call volume down
bind = , XF86AudioMute, exec, qs ipc call volume mute
# <<< quickshell <<<
EOF

# Turn off waybar and mako autostart so they don't overlap the shell
sed -i -E 's/^(exec-once.*\b(waybar|mako)\b.*)$/# \1  # disabled by quickshell installer/' "$HYPR"/*.conf 2>/dev/null || true

# Kitty: include the generated theme once
grep -qxF "include theme.conf" "$KITTY/kitty.conf" || echo "include theme.conf" >> "$KITTY/kitty.conf"

# Flag Omarchy binds that may clash with ours
for key in "SUPER, SPACE" "SUPER, M," "SUPER, T," "SUPER, D,"; do
    if grep -rqi "^bind.*$key" "$HYPR" --exclude="hyprland.conf" 2>/dev/null; then
        warn "Possible keybind conflict with '$key' in $HYPR (check bindings.conf)"
    fi
done

# ---------------------------------------------------------------- apply and start
say "Applying default theme"
"$QS/scripts/apply-theme.sh" tokyo-night || warn "Theme apply reported an error"

say "Restarting shell"
pkill -x waybar 2>/dev/null || true
pkill -x mako 2>/dev/null || true
pkill -x quickshell 2>/dev/null || true
hyprctl reload >/dev/null 2>&1 || warn "Hyprland not running; reload it later with hyprctl reload"
setsid quickshell >/dev/null 2>&1 < /dev/null &

say "Done"
cat <<EOF
Installed to $QS
Backups: $QS-backup-$STAMP (if an old config existed) and *.bak-$STAMP in $HYPR and $KITTY

Keys: SUPER+Space apps, SUPER+M menu, SUPER+T themes, SUPER+D displays, Print screenshot
Check the terminal if the bar doesn't appear: run 'quickshell' to see QML errors.
Reboot or log out and back in to make sure everything autostarts.
EOF
