import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick

PanelWindow {
    id: panel

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Colors. Change these to match your theme.
    readonly property color bg: "#1a1b26"
    readonly property color fg: "#c0caf5"
    readonly property color accent: "#7aa2f7"
    readonly property color surface: "#24283b"
    readonly property color muted: "#565f89"
    readonly property string font: "JetBrainsMono Nerd Font"

    // Screens. Names must match `hyprctl monitors all`.
    readonly property string laptop: "eDP-1"
    readonly property string external: "HDMI-A-1"

    // Wanted modes. If a mode is not offered by the screen, "preferred" is used instead.
    readonly property string laptopMode: "1920x1080@120.003"
    readonly property string externalMode: "1920x1080@100.000"
    readonly property string mirrorMode: "1920x1080@60.00"

    // Same files the mirror toggle uses
    readonly property string stateFile: "/home/pranjal/.config/quickshell/state/mirror"
    readonly property string mirrorLua: "/home/pranjal/.config/hypr/mirror.lua"

    // Where a screen waits while the other one is moved, so no step ever overlaps
    readonly property int parkAt: 10000

    // Live state, refreshed from hyprctl every time the panel opens
    property var monInfo: ({})
    property bool laptopPresent: true
    property bool externalPresent: false
    property bool laptopOn: true
    property bool externalOn: false
    property int laptopW: 1920
    property int laptopH: 1080
    property int externalW: 1920
    property int externalH: 1080

    property string side: "right"          // where the external screen sits: left, right, above, below
    property string layout: "extend"       // extend, mirror, laptop, screen
    property string status: ""
    property string pendingStatus: ""
    property string lastError: ""
    property bool busy: false

    // Top-left corner of each screen, in logical pixels, for the chosen side
    readonly property var pos: positionsFor(side)

    function positionsFor(s) {
        if (s === "left")  return { ex: externalW, ey: 0, hx: 0, hy: 0 }
        if (s === "above") return { ex: 0, ey: externalH, hx: 0, hy: 0 }
        if (s === "below") return { ex: 0, ey: 0, hx: 0, hy: laptopH }
        return { ex: 0, ey: 0, hx: laptopW, hy: 0 }     // right
    }

    // ---------- modes ----------

    // Picks a mode the screen really offers, so a wrong refresh rate can't break the layout
    function modeChoice(name, wanted) {
        const m = monInfo[name]
        const mt = /^(\d+)x(\d+)@([\d.]+)/.exec(wanted)
        var fw = mt ? parseInt(mt[1]) : 1920
        var fh = mt ? parseInt(mt[2]) : 1080
        if (m && m.width > 0 && m.height > 0) { fw = m.width; fh = m.height }
        const fallback = { str: "preferred", w: fw, h: fh }
        if (!m || !mt) return fallback

        const want = parseFloat(mt[3])
        const modes = m.availableModes || []
        for (var i = 0; i < modes.length; i++) {
            const r = /^(\d+)x(\d+)@([\d.]+)/.exec(modes[i])
            if (r && parseInt(r[1]) === parseInt(mt[1]) && parseInt(r[2]) === parseInt(mt[2])
                && Math.abs(parseFloat(r[3]) - want) < 0.5)
                return { str: r[1] + "x" + r[2] + "@" + r[3], w: parseInt(r[1]), h: parseInt(r[2]) }
        }
        return fallback
    }

    // ---------- Lua lines for hyprctl eval ----------

    function edpAt(x, y, on) {
        if (!on) return 'hl.monitor({ output = "' + laptop + '", disabled = true })'
        return 'hl.monitor({ output = "' + laptop + '", mode = "' + modeChoice(laptop, laptopMode).str
            + '", position = "' + x + 'x' + y + '", scale = 1, disabled = false })'
    }

    function hdmiAt(x, y, on) {
        if (!on) return 'hl.monitor({ output = "' + external + '", disabled = true })'
        return 'hl.monitor({ output = "' + external + '", mode = "' + modeChoice(external, externalMode).str
            + '", position = "' + x + 'x' + y + '", scale = 1, disabled = false })'
    }

    function hdmiMirrorLine() {
        return 'hl.monitor({ output = "' + external + '", mode = "' + modeChoice(external, mirrorMode).str
            + '", position = "0x0", scale = 1, mirror = "' + laptop + '" })'
    }

    // ---------- command queue: one hyprctl/sh call at a time ----------

    property var queue: []

    function run(args) {
        queue.push(args)
        pump()
    }

    function pump() {
        if (runner.running) return
        if (queue.length === 0) {
            if (busy) {
                busy = false
                settle.restart()
            }
            return
        }
        busy = true
        runner.command = queue.shift()
        runner.running = true
    }

    function evalLua(lua) { run(["hyprctl", "eval", lua]) }

    // Writes or clears the mirror state the mirror toggle also reads
    function writeMirror(on) {
        if (on) {
            run(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"", "sh", stateFile])
            run(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "sh", hdmiMirrorLine(), mirrorLua])
        } else {
            run(["rm", "-f", stateFile])
            run(["sh", "-c", "printf '%s\\n' \"$1\" > \"$2\"", "sh", "-- Mirror off", mirrorLua])
        }
    }

    // Moves a screen far away (still enabled) so the other one can take its place
    function parkExternal() { if (externalOn) evalLua(hdmiAt(parkAt, parkAt, true)) }
    function parkLaptop() { if (laptopOn) evalLua(edpAt(parkAt, parkAt, true)) }

    // ---------- layouts ----------
    // Every step keeps at least one screen on and never lets two screens overlap.

    function setLayout(name) {
        if (busy) { status = "Still applying the last change."; return }
        if (!externalPresent && name !== "laptop") {
            status = external + " is not connected."
            return
        }

        lastError = ""
        layout = name
        status = "Applying..."

        if (name === "extend") {
            writeMirror(false)
            parkExternal()
            evalLua(edpAt(pos.ex, pos.ey, true))
            evalLua(hdmiAt(pos.hx, pos.hy, true))
            pendingStatus = "Extend. Second screen on the " + side + "."
        } else if (name === "mirror") {
            writeMirror(true)
            parkExternal()
            evalLua(edpAt(0, 0, true))
            evalLua(hdmiMirrorLine())
            pendingStatus = "Mirror."
        } else if (name === "laptop") {
            writeMirror(false)
            parkExternal()
            evalLua(edpAt(0, 0, true))
            if (externalPresent) evalLua(hdmiAt(0, 0, false))
            pendingStatus = "Laptop only."
        } else if (name === "screen") {
            writeMirror(false)
            parkLaptop()
            evalLua(hdmiAt(0, 0, true))
            evalLua(edpAt(0, 0, false))
            pendingStatus = "Screen only."
        }

        pump()
    }

    function setSide(s) {
        side = s
        if (layout === "extend" || layout === "mirror") setLayout(layout)
    }

    function cycleLayout() {
        const order = externalPresent ? ["extend", "mirror", "laptop", "screen"] : ["laptop"]
        setLayout(order[(order.indexOf(layout) + 1) % order.length])
    }

    // ---------- reading live state ----------

    function refresh() { reader.running = true }

    function parse(text) {
        try {
            const all = JSON.parse(text)
            var info = {}
            all.forEach(function (m) { info[m.name] = m })
            monInfo = info

            const lap = info[laptop]
            const ext = info[external]

            laptopPresent = !!lap
            externalPresent = !!ext
            laptopOn = !!lap && !lap.disabled
            externalOn = !!ext && !ext.disabled

            if (lap) { const c = modeChoice(laptop, laptopMode); laptopW = c.w; laptopH = c.h }
            if (ext) { const c2 = modeChoice(external, externalMode); externalW = c2.w; externalH = c2.h }

            const mo = ext ? ext.mirrorOf : undefined
            const mirrored = mo !== undefined && mo !== null && mo !== "none" && mo !== "" && mo !== -1

            if (!ext || !externalOn) {
                layout = "laptop"
            } else if (!laptopOn) {
                layout = "screen"
            } else if (mirrored) {
                layout = "mirror"
            } else {
                layout = "extend"
                // Read which side the second screen is really on
                if (ext.x >= lap.x + laptopW) side = "right"
                else if (ext.x + externalW <= lap.x) side = "left"
                else if (ext.y >= lap.y + laptopH) side = "below"
                else if (ext.y + externalH <= lap.y) side = "above"
            }

            if (lastError !== "") status = "Error: " + lastError
            else if (!externalPresent) status = external + " is not connected."
            else status = pendingStatus
            pendingStatus = ""
        } catch (e) {
            status = "Could not read monitor state."
        }
        pickScreen()
    }

    // Show the panel on the focused screen, and move it if that screen goes away
    function pickScreen() {
        const fm = Hyprland.focusedMonitor
        const name = fm ? fm.name : ""
        const s = Quickshell.screens.find(x => x.name === name) || Quickshell.screens[0]
        if (s) screen = s
    }

    function open() {
        if (!visible) pickScreen()
        visible = true
    }
    function toggle() {
        if (!visible) pickScreen()
        visible = !visible
    }

    onVisibleChanged: {
        if (visible) {
            lastError = ""
            pendingStatus = ""
            refresh()
            scope.forceActiveFocus()
        }
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: panel.refresh()
    }

    Process {
        id: reader
        command: ["hyprctl", "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: panel.parse(this.text)
        }
    }

    Process {
        id: runner
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                if (t.length > 0 && t !== "ok") {
                    panel.lastError = t
                    panel.status = "Error: " + t
                }
            }
        }
        onRunningChanged: if (!running) panel.pump()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: panel.visible = false
        Keys.onTabPressed: panel.cycleLayout()
        Keys.onLeftPressed: panel.setSide("left")
        Keys.onRightPressed: panel.setSide("right")
        Keys.onUpPressed: panel.setSide("above")
        Keys.onDownPressed: panel.setSide("below")
        Keys.onPressed: (ev) => {
            const order = ["extend", "mirror", "laptop", "screen"]
            const i = ev.key - Qt.Key_1
            if (i >= 0 && i < order.length) {
                panel.setLayout(order[i])
                ev.accepted = true
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 620
            height: col.implicitHeight + 40
            radius: 12
            color: panel.bg
            border.color: panel.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 14

                Text {
                    text: "DISPLAY   1-4 or Tab layout   arrows move second screen   Esc close"
                    color: panel.muted
                    font.family: panel.font
                    font.pixelSize: 11
                }

                // Arrangement map, drawn to scale
                Item {
                    id: map
                    width: parent.width
                    height: 180

                    readonly property real gap: 16
                    readonly property real minX: Math.min(panel.pos.ex, panel.pos.hx)
                    readonly property real minY: Math.min(panel.pos.ey, panel.pos.hy)
                    readonly property real spanW: Math.max(panel.pos.ex + panel.laptopW, panel.pos.hx + panel.externalW) - minX
                    readonly property real spanH: Math.max(panel.pos.ey + panel.laptopH, panel.pos.hy + panel.externalH) - minY
                    readonly property real k: Math.min((width - 2 * gap) / spanW, (height - 2 * gap) / spanH)

                    Rectangle {
                        visible: panel.layout !== "screen"
                        color: panel.surface
                        border.color: panel.accent
                        radius: 6
                        width: panel.laptopW * map.k
                        height: panel.laptopH * map.k
                        x: (panel.pos.ex - map.minX) * map.k + map.gap
                        y: (panel.pos.ey - map.minY) * map.k + map.gap

                        Text {
                            anchors.centerIn: parent
                            text: panel.laptop
                            color: panel.fg
                            font.family: panel.font
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        visible: panel.externalOn
                        color: panel.surface
                        border.color: panel.muted
                        radius: 6
                        width: panel.externalW * map.k
                        height: panel.externalH * map.k
                        x: (panel.pos.hx - map.minX) * map.k + map.gap
                        y: (panel.pos.hy - map.minY) * map.k + map.gap

                        Text {
                            anchors.centerIn: parent
                            text: panel.external
                            color: panel.fg
                            font.family: panel.font
                            font.pixelSize: 12
                        }
                    }
                }

                // Layout buttons
                Row {
                    spacing: 8

                    Repeater {
                        model: [
                            { id: "extend", label: "1 Extend" },
                            { id: "mirror", label: "2 Mirror" },
                            { id: "laptop", label: "3 Laptop only" },
                            { id: "screen", label: "4 Screen only" }
                        ]

                        Rectangle {
                            required property var modelData
                            width: 130
                            height: 34
                            radius: 6
                            opacity: (!panel.externalPresent && modelData.id !== "laptop") ? 0.4 : 1
                            color: panel.layout === modelData.id ? panel.accent : panel.surface

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: panel.layout === modelData.id ? panel.bg : panel.fg
                                font.family: panel.font
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: panel.setLayout(modelData.id)
                            }
                        }
                    }
                }

                // Side picker, for extend and mirror
                Row {
                    spacing: 6
                    visible: panel.layout === "extend" || panel.layout === "mirror"

                    Text {
                        text: "Second screen on the"
                        color: panel.muted
                        font.family: panel.font
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Repeater {
                        model: ["left", "right", "above", "below"]

                        Rectangle {
                            required property string modelData
                            width: 64
                            height: 26
                            radius: 6
                            color: panel.side === modelData ? panel.accent : panel.surface

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: panel.side === modelData ? panel.bg : panel.fg
                                font.family: panel.font
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: panel.setSide(modelData)
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: panel.status
                    color: panel.lastError !== "" ? "#f7768e" : panel.muted
                    font.family: panel.font
                    font.pixelSize: 11
                }
            }
        }
    }
}
