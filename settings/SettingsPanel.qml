import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: panel

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property color bg: "#1a1b26"
    readonly property color fg: "#c0caf5"
    readonly property color accent: "#f8bb71"
    readonly property color surface: "#24283b"
    readonly property color muted: "#565f89"
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string home: Quickshell.env("HOME")
    readonly property string cfgPath: home + "/.config/quickshell/state/bar.json"
    readonly property string barShell: home + "/CustomQuickshell/bar/shell.qml"

    readonly property var defaults: ({
        position: "top", height: 36, opacity: 1.0, radius: 0,
        showWorkspaces: true, showTitle: true, showNetwork: true, showVolume: true,
        showBattery: true, showClock: true, clockFormat: "ddd dd MMM  HH:mm",
        useDmsColors: true,
        colors: { bg: "#1a1b26", surface: "#24283b", fg: "#c0caf5", accent: "#7aa2f7" }
    })

    property var cfg: defaults
    property int tab: 0
    property string output: ""

    readonly property var toggles: [
        { key: "showWorkspaces", label: "Workspaces" },
        { key: "showTitle", label: "Window title" },
        { key: "showNetwork", label: "Network" },
        { key: "showVolume", label: "Volume" },
        { key: "showBattery", label: "Battery" },
        { key: "showClock", label: "Clock" },
        { key: "useDmsColors", label: "Use DMS colors" }
    ]

    readonly property var clockFormats: [
        "ddd dd MMM  HH:mm",
        "HH:mm",
        "hh:mm AP"
    ]

    readonly property var actions: [
        { label: "Display layouts", cmd: "qs -p " + home + "/CustomQuickshell/window-tool/shell.qml ipc call displaypanel toggle" },
        { label: "Mirror on / off", cmd: home + "/.config/quickshell/scripts/mirror-toggle.sh" },
        { label: "Window placement", cmd: "qs -p " + home + "/CustomQuickshell/window-tool/shell.qml ipc call windowtool toggle" },
        { label: "Screenshot: region", cmd: home + "/.config/quickshell/scripts/screenshot.sh region" },
        { label: "Screenshot: full", cmd: home + "/.config/quickshell/scripts/screenshot.sh full" },
        { label: "Wallpaper picker (DMS)", cmd: "dms ipc call dankdash wallpaper" },
        { label: "Sync keyboard color", cmd: home + "/.local/bin/wallpaper-keyboard-rgb-apply" },
        { label: "Reload Hyprland", cmd: "hyprctl reload" },
        { label: "Show config errors", cmd: "hyprctl configerrors" },
        { label: "Lock screen", cmd: "loginctl lock-session" }
    ]

    function open() { visible = true }
    function toggle() { visible = !visible }

    onVisibleChanged: if (visible) scope.forceActiveFocus()

    // ---------- reading and writing bar.json ----------

    FileView {
        path: panel.cfgPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { panel.cfg = Object.assign({}, panel.defaults, JSON.parse(text())) }
            catch (e) { panel.output = "bar.json is invalid: " + e.message }
        }
        onLoadFailed: panel.cfg = panel.defaults
    }

    function setKey(key, value) {
        const next = Object.assign({}, cfg)
        next[key] = value
        cfg = next
        writer.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\"; printf '%s\\n' \"$2\" > \"$1\"",
            "sh", cfgPath, JSON.stringify(next, null, 2)]
        writer.running = true
    }

    function bump(key, delta, lo, hi) {
        const v = Math.round((cfg[key] + delta) * 10) / 10
        setKey(key, Math.max(lo, Math.min(hi, v)))
    }

    Process { id: writer }

    // ---------- actions ----------

    function run(cmd) {
        output = "Running..."
        runner.command = ["sh", "-c", cmd + " 2>&1"]
        runner.running = true
    }

    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                panel.output = t.length > 0 ? t.slice(-400) : "Done"
            }
        }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: panel.visible = false
        Keys.onLeftPressed: panel.tab = (panel.tab + 1) % 2
        Keys.onRightPressed: panel.tab = (panel.tab + 1) % 2

        MouseArea {
            anchors.fill: parent
            onClicked: panel.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 640
            height: body.implicitHeight + 40
            radius: 12
            color: panel.bg
            border.color: panel.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 14

                Text {
                    text: "SETTINGS   ←→ section   Esc close"
                    color: panel.muted
                    font.family: panel.font
                    font.pixelSize: 11
                }

                Row {
                    spacing: 6
                    Chip {
                        text: "Bar"
                        fill: panel.tab === 0 ? panel.accent : panel.surface
                        textColor: panel.tab === 0 ? panel.bg : panel.fg
                        onClicked: panel.tab = 0
                    }
                    Chip {
                        text: "Actions"
                        fill: panel.tab === 1 ? panel.accent : panel.surface
                        textColor: panel.tab === 1 ? panel.bg : panel.fg
                        onClicked: panel.tab = 1
                    }
                }

                // ---------- Bar tab ----------
                Column {
                    width: parent.width
                    spacing: 12
                    visible: panel.tab === 0

                    Text { text: "POSITION"; color: panel.muted; font.family: panel.font; font.pixelSize: 11 }
                    Row {
                        spacing: 6
                        Chip {
                            text: "Top"
                            fill: panel.cfg.position !== "bottom" ? panel.accent : panel.surface
                            textColor: panel.cfg.position !== "bottom" ? panel.bg : panel.fg
                            onClicked: panel.setKey("position", "top")
                        }
                        Chip {
                            text: "Bottom"
                            fill: panel.cfg.position === "bottom" ? panel.accent : panel.surface
                            textColor: panel.cfg.position === "bottom" ? panel.bg : panel.fg
                            onClicked: panel.setKey("position", "bottom")
                        }
                    }

                    Text { text: "SIZE"; color: panel.muted; font.family: panel.font; font.pixelSize: 11 }
                    Row {
                        spacing: 6
                        Chip { text: "height -"; fill: panel.surface; textColor: panel.fg; onClicked: panel.setKey("height", Math.max(24, panel.cfg.height - 2)) }
                        Text { text: panel.cfg.height + " px"; color: panel.fg; font.family: panel.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Chip { text: "height +"; fill: panel.surface; textColor: panel.fg; onClicked: panel.setKey("height", Math.min(60, panel.cfg.height + 2)) }
                    }
                    Row {
                        spacing: 6
                        Chip { text: "opacity -"; fill: panel.surface; textColor: panel.fg; onClicked: panel.bump("opacity", -0.1, 0.3, 1.0) }
                        Text { text: "opacity " + Math.round(panel.cfg.opacity * 100) + "%"; color: panel.fg; font.family: panel.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Chip { text: "opacity +"; fill: panel.surface; textColor: panel.fg; onClicked: panel.bump("opacity", 0.1, 0.3, 1.0) }
                    }
                    Row {
                        spacing: 6
                        Chip { text: "corners -"; fill: panel.surface; textColor: panel.fg; onClicked: panel.setKey("radius", Math.max(0, panel.cfg.radius - 2)) }
                        Text { text: "corner radius " + panel.cfg.radius; color: panel.fg; font.family: panel.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Chip { text: "corners +"; fill: panel.surface; textColor: panel.fg; onClicked: panel.setKey("radius", Math.min(20, panel.cfg.radius + 2)) }
                    }

                    Text { text: "MODULES"; color: panel.muted; font.family: panel.font; font.pixelSize: 11 }
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: panel.toggles
                            Chip {
                                required property var modelData
                                text: modelData.label + (panel.cfg[modelData.key] ? ": on" : ": off")
                                fill: panel.cfg[modelData.key] ? panel.accent : panel.surface
                                textColor: panel.cfg[modelData.key] ? panel.bg : panel.fg
                                onClicked: panel.setKey(modelData.key, !panel.cfg[modelData.key])
                            }
                        }
                    }

                    Text { text: "CLOCK FORMAT"; color: panel.muted; font.family: panel.font; font.pixelSize: 11 }
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: panel.clockFormats
                            Chip {
                                required property string modelData
                                text: modelData
                                fill: panel.cfg.clockFormat === modelData ? panel.accent : panel.surface
                                textColor: panel.cfg.clockFormat === modelData ? panel.bg : panel.fg
                                onClicked: panel.setKey("clockFormat", modelData)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Bar is started by: quickshell -p " + panel.barShell + "   (turn off the DMS bar so there is only one)"
                        color: panel.muted
                        font.family: panel.font
                        font.pixelSize: 10
                    }
                }

                // ---------- Actions tab ----------
                Column {
                    width: parent.width
                    spacing: 6
                    visible: panel.tab === 1

                    Repeater {
                        model: panel.actions
                        Rectangle {
                            required property var modelData
                            width: body.width
                            height: 32
                            radius: 6
                            color: panel.surface

                            Text {
                                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                text: modelData.label
                                color: panel.fg
                                font.family: panel.font
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: panel.run(modelData.cmd)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(40, outText.implicitHeight + 16)
                    radius: 6
                    color: panel.surface

                    Text {
                        id: outText
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                        text: panel.output === "" ? "Changes save automatically. Output appears here." : panel.output
                        color: panel.muted
                        wrapMode: Text.WrapAnywhere
                        font.family: panel.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}