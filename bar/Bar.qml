import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: bar

    readonly property string home: Quickshell.env("HOME")
    readonly property string configPath: home + "/.config/quickshell/state/bar.json"
    readonly property string dmsPath: home + "/.config/kitty/dank-theme.conf"

    readonly property var defaults: ({
        position: "top",
        floating: true,
        margin: 8,
        height: 40,
        opacity: 0.92,
        showWorkspaces: true,
        showTitle: true,
        showNetwork: true,
        showVolume: true,
        showBattery: true,
        showClock: true,
        clockFormat: "ddd dd MMM  HH:mm",
        useDmsColors: true,
        colors: { bg: "#1a1b26", surface: "#24283b", fg: "#c0caf5", accent: "#7aa2f7", red: "#f7768e" }
    })

    property var cfg: defaults
    property var dms: ({})

    property string network: "offline"
    property var wifiList: []
    property string wifiMsg: ""

    property int volume: 0
    property bool muted: false

    property int battery: -1
    property string batStatus: ""

    property string menu: ""        // "", "network", "volume", "battery", "clock"

    readonly property var now: clock.date
    readonly property real m: cfg.floating ? cfg.margin : 0
    readonly property real islandH: cfg.height - 8

    readonly property var dmsMap: ({
        bg: "background", fg: "foreground", accent: "cursor",
        surface: "selection_background", red: "color1"
    })

    function colorOf(k) {
        if (cfg.useDmsColors && dms[k]) return dms[k]
        return (cfg.colors && cfg.colors[k]) || defaults.colors[k]
    }

    readonly property color cBg: colorOf("bg")
    readonly property color cFg: colorOf("fg")
    readonly property color cAccent: colorOf("accent")
    readonly property color cSurface: colorOf("surface")
    readonly property color cRed: colorOf("red")
    readonly property color island: Qt.alpha(cBg, cfg.opacity)
    readonly property color edge: Qt.alpha(cFg, 0.08)
    readonly property color muteFg: Qt.alpha(cFg, 0.45)

    function parseKitty(text) {
        const raw = {}
        text.split("\n").forEach(line => {
            const parts = line.trim().split(/\s+/)
            if (parts.length >= 2 && parts[0].charAt(0) !== "#") raw[parts[0]] = parts[1]
        })
        const out = {}
        Object.keys(dmsMap).forEach(k => { if (raw[dmsMap[k]]) out[k] = raw[dmsMap[k]] })
        return out
    }

    // Nerd Font glyphs
    function wifiIcon() { return "\uf1eb" }
    function volIcon() { return muted ? "\uf026" : (volume >= 50 ? "\uf028" : "\uf027") }
    function batIcon() {
        if (batStatus.indexOf("Charging") >= 0) return "\uf0e7"
        if (battery >= 90) return "\uf240"
        if (battery >= 65) return "\uf241"
        if (battery >= 40) return "\uf242"
        if (battery >= 15) return "\uf243"
        return "\uf244"
    }

    readonly property var workspaceList: {
        const all = Hyprland.workspaces.values.filter(w => w.id > 0)
        const shown = all.filter(w => w.id <= 10 || w.active || w.focused || (w.lastIpcObject?.windows ?? 0) > 0)
        return (shown.length > 0 ? shown : all).sort((a, b) => a.id - b.id)
    }

    // Calendar cells for the month of d: 42 entries, 0 for empty
    function monthCells(d) {
        const y = d.getFullYear(), mo = d.getMonth()
        const first = new Date(y, mo, 1).getDay()
        const days = new Date(y, mo + 1, 0).getDate()
        const cells = []
        for (let i = 0; i < 42; i++) {
            const day = i - first + 1
            cells.push(day >= 1 && day <= days ? day : 0)
        }
        return cells
    }

    function toggleMenu(name) {
        menu = (menu === name) ? "" : name
        if (menu === "network") { netProc.running = true; netList.running = true }
        if (menu === "volume") volProc.running = true
        if (menu === "battery") batProc.running = true
    }

    function setVolume(arg) {
        volAct.command = ["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", arg]
        volAct.running = true
    }

    function toggleMute() { muteProc.running = true }

    function connectWifi(ssid) {
        wifiMsg = "Connecting to " + ssid + "..."
        wifiAct.command = ["sh", "-c", "nmcli dev wifi connect \"$1\" 2>&1", "sh", ssid]
        wifiAct.running = true
    }

    function setWifi(on) {
        wifiMsg = on ? "Turning Wi-Fi on..." : "Turning Wi-Fi off..."
        wifiAct.command = ["sh", "-c", "nmcli radio wifi " + (on ? "on" : "off") + " 2>&1"]
        wifiAct.running = true
    }

    anchors {
        top: cfg.position !== "bottom"
        bottom: cfg.position === "bottom"
        left: true
        right: true
    }
    margins { top: m; bottom: m; left: m; right: m }
    implicitHeight: cfg.height
    exclusiveZone: cfg.height + m
    color: "transparent"

    FileView {
        path: bar.configPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { bar.cfg = Object.assign({}, bar.defaults, JSON.parse(text())) }
            catch (e) { bar.cfg = bar.defaults }
        }
        onLoadFailed: bar.cfg = bar.defaults
    }

    FileView {
        path: bar.dmsPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: bar.dms = bar.parseKitty(text())
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ---------- processes ----------

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: bar.network = this.text.trim() || "offline"
        }
    }

    Process {
        id: netList
        command: ["sh", "-c", "nmcli -t -f IN-USE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const seen = {}
                this.text.split("\n").forEach(line => {
                    const i = line.indexOf(":")
                    const j = line.indexOf(":", i + 1)
                    if (i < 0 || j < 0) return
                    const ssid = line.slice(j + 1)
                    if (!ssid || seen[ssid]) return
                    seen[ssid] = true
                    out.push({
                        active: line.slice(0, i) === "*",
                        signal: parseInt(line.slice(i + 1, j)) || 0,
                        ssid: ssid
                    })
                })
                out.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                bar.wifiList = out.slice(0, 12)
            }
        }
    }

    Process {
        id: wifiAct
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim().split("\n").pop()
                bar.wifiMsg = t || "Done"
                netProc.running = true
                netList.running = true
            }
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const g = this.text.match(/([\d.]+)/)
                if (g) bar.volume = Math.round(parseFloat(g[1]) * 100)
                bar.muted = this.text.indexOf("MUTED") >= 0
            }
        }
    }

    Process {
        id: volAct
        onRunningChanged: if (!running) volProc.running = true
    }

    Process {
        id: muteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onRunningChanged: if (!running) volProc.running = true
    }

    // First BAT* device, so BAT1 and other names work too
    Process {
        id: batProc
        command: ["sh", "-c",
            "for b in /sys/class/power_supply/BAT*; do [ -r \"$b/capacity\" ] && { echo \"$(cat \"$b/capacity\") $(cat \"$b/status\")\"; break; }; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim().split(" ")
                const v = parseInt(p[0])
                bar.battery = isNaN(v) ? -1 : v
                bar.batStatus = p.slice(1).join(" ")
            }
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true
            volProc.running = true
            batProc.running = true
        }
    }

    // Solid strip, only when the bar is not floating
    Rectangle {
        anchors.fill: parent
        visible: !bar.cfg.floating
        color: bar.island
    }

    // ---------- left: workspaces ----------

    Island {
        visible: bar.cfg.showWorkspaces
        anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
        height: bar.islandH
        width: wsRow.implicitWidth + 12
        surface: bar.island
        edge: bar.edge

        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 4

            Repeater {
                model: bar.workspaceList

                Rectangle {
                    required property var modelData
                    readonly property bool active: modelData.active === true

                    height: 24
                    width: active ? 36 : 26
                    radius: height / 2
                    color: active ? bar.cAccent
                        : (wsHover.containsMouse ? Qt.alpha(bar.cFg, 0.16) : Qt.alpha(bar.cFg, 0.06))

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: active ? bar.cBg : bar.cFg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: active
                    }

                    MouseArea {
                        id: wsHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.activate()
                    }
                }
            }
        }
    }

    // ---------- center: focused window title ----------

    Island {
        id: titleIsland
        visible: bar.cfg.showTitle && (Hyprland.activeToplevel?.title ?? "") !== ""
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter }
        height: bar.islandH
        width: titleText.width + 28
        surface: bar.island
        edge: bar.edge

        Text {
            id: titleText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, 440)
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: Hyprland.activeToplevel?.title ?? ""
            color: bar.cFg
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }
    }

    // ---------- right: status and clock ----------

    Island {
        anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        height: bar.islandH
        width: statusRow.implicitWidth + 12
        surface: bar.island
        edge: bar.edge

        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: 2

            Chip {
                visible: bar.cfg.showNetwork
                icon: bar.wifiIcon()
                text: bar.network === "offline" ? "off" : bar.network
                fill: bar.menu === "network" ? Qt.alpha(bar.cAccent, 0.22) : "transparent"
                textColor: bar.network === "offline" ? bar.muteFg : bar.cFg
                onClicked: bar.toggleMenu("network")
            }

            Item { visible: bar.cfg.showNetwork && bar.cfg.showVolume; width: 9; height: 28
                Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: bar.edge }
            }

            Chip {
                visible: bar.cfg.showVolume
                icon: bar.volIcon()
                text: bar.muted ? "muted" : bar.volume + "%"
                fill: bar.menu === "volume" ? Qt.alpha(bar.cAccent, 0.22) : "transparent"
                textColor: bar.muted ? bar.muteFg : bar.cFg
                onClicked: bar.toggleMenu("volume")
            }

            Item { visible: bar.cfg.showVolume && bar.cfg.showBattery && bar.battery >= 0; width: 9; height: 28
                Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: bar.edge }
            }

            Chip {
                visible: bar.cfg.showBattery && bar.battery >= 0
                icon: bar.batIcon()
                text: bar.battery + "%"
                fill: bar.menu === "battery" ? Qt.alpha(bar.cAccent, 0.22) : "transparent"
                textColor: bar.battery <= 15 ? bar.cRed : bar.cFg
                iconColor: bar.battery <= 15 ? bar.cRed : bar.cFg
                onClicked: bar.toggleMenu("battery")
            }

            Item { visible: bar.cfg.showClock; width: 9; height: 28
                Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: bar.edge }
            }

            Chip {
                visible: bar.cfg.showClock
                icon: "\uf017"
                text: Qt.formatDateTime(clock.date, bar.cfg.clockFormat)
                fill: bar.menu === "clock" ? bar.cFg : bar.cAccent
                textColor: bar.cBg
                onClicked: bar.toggleMenu("clock")
            }
        }
    }
}