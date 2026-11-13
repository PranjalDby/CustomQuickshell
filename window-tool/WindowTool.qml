import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: tool

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

    readonly property int topReserve: 40     // space kept free for the DMS bar, logical px
    readonly property int canvasW: 740
    readonly property int canvasH: 360
    readonly property int pad: 16
    readonly property real snapPx: 10

    property var monitors: []                // [{ name, x, y, w, h }] logical px
    property var win: null                   // { address, floating, x, y, w, h, title }
    property var orig: null                  // window as it was when the panel opened
    property string status: ""

    readonly property var bounds: boundsOf(monitors)
    readonly property real s: monitors.length > 0
        ? Math.min((canvasW - 2 * pad) / bounds.w, (canvasH - 2 * pad) / bounds.h) : 1
    readonly property real offX: pad + ((canvasW - 2 * pad) - bounds.w * s) / 2
    readonly property real offY: pad + ((canvasH - 2 * pad) - bounds.h * s) / 2

    // f = [x, y, w, h] as fractions of a monitor's usable area (below the bar)
    readonly property var presets: [
        { label: "Full",         f: [0, 0, 1, 1] },
        { label: "Center",       f: [0.2, 0.125, 0.6, 0.75] },
        { label: "Left",         f: [0, 0, 0.5, 1] },
        { label: "Right",        f: [0.5, 0, 0.5, 1] },
        { label: "Top",          f: [0, 0, 1, 0.5] },
        { label: "Bottom",       f: [0, 0.5, 1, 0.5] },
        { label: "Top-left",     f: [0, 0, 0.5, 0.5] },
        { label: "Top-right",    f: [0.5, 0, 0.5, 0.5] },
        { label: "Bottom-left",  f: [0, 0.5, 0.5, 0.5] },
        { label: "Bottom-right", f: [0.5, 0.5, 0.5, 0.5] }
    ]

    function open() { visible = true }
    function toggle() { visible = !visible }

    // ---------- geometry ----------

    function boundsOf(ms) {
        if (ms.length === 0) return { x: 0, y: 0, w: 1920, h: 1080 }
        var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
        ms.forEach(function (m) {
            x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y)
            x1 = Math.max(x1, m.x + m.w); y1 = Math.max(y1, m.y + m.h)
        })
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    }

    function toPx(gx) { return offX + (gx - bounds.x) * s }
    function toPy(gy) { return offY + (gy - bounds.y) * s }

    function setRect(x, y, w, h) {
        const b = bounds
        x = Math.max(b.x, Math.min(x, b.x + b.w - w))
        y = Math.max(b.y, Math.min(y, b.y + b.h - h))
        win = Object.assign({}, win, { x: Math.round(x), y: Math.round(y), w: Math.round(w), h: Math.round(h) })
    }

    function snapTo(v, cands) {
        var best = v, bd = snapPx / s
        cands.forEach(function (c) {
            const d = Math.abs(c - v)
            if (d < bd) { bd = d; best = c }
        })
        return best
    }

    // Snap targets: monitor edges and centers
    function candX(w) {
        var c = []
        monitors.forEach(function (m) { c.push(m.x, m.x + m.w - w, m.x + (m.w - w) / 2, m.x - w, m.x + m.w) })
        return c
    }
    function candY(h) {
        var c = []
        monitors.forEach(function (m) {
            c.push(m.y + topReserve, m.y + m.h - h, m.y + topReserve + (m.h - topReserve - h) / 2, m.y - h, m.y + m.h)
        })
        return c
    }
    function candRight() {
        var c = []
        monitors.forEach(function (m) { c.push(m.x + m.w, m.x) })
        return c
    }
    function candBottom() {
        var c = []
        monitors.forEach(function (m) { c.push(m.y + m.h) })
        return c
    }

    // ---------- presets ----------

    function applyPreset(i) {
        const p = presets[i]
        if (!win) { status = "No focused window."; return }

        // Use the monitor the window is mostly on
        const cx = win.x + win.w / 2
        const cy = win.y + win.h / 2
        const m = monitors.find(mm => cx >= mm.x && cx < mm.x + mm.w && cy >= mm.y && cy < mm.y + mm.h)
            || monitors[0]
        if (!m) return

        const uh = m.h - topReserve
        setRect(m.x + p.f[0] * m.w, m.y + topReserve + p.f[1] * uh, p.f[2] * m.w, p.f[3] * uh)
        status = "Preset: " + p.label + ". Press Enter or Apply."
    }

    // ---------- applying to the real window ----------

    // Lua calls for the focused window. The move and resize lines use the form
    // from your bindings. If the test in the README fails, change these two lines
    // to the form that worked.
    function windowCommands(w) {
        var cmds = []
        if (!w.floating) cmds.push('hl.dsp.window.float({ action = "toggle" })')
        cmds.push('hl.dsp.window.resize({ x = ' + Math.round(w.w) + ', y = ' + Math.round(w.h) + ' })')
        cmds.push('hl.dsp.window.move({ x = ' + Math.round(w.x) + ', y = ' + Math.round(w.y) + ' })')
        return cmds
    }

    function apply() {
        if (!win) { status = "No focused window."; return }
        windowCommands(win).forEach(function (lua) { run(["hyprctl", "eval", lua]) })
        orig = Object.assign({}, win, { floating: true })
        win = Object.assign({}, win, { floating: true })
        status = "Applied " + win.w + " x " + win.h + " at " + win.x + "," + win.y + "."
    }

    function revert() {
        if (!orig) return
        win = Object.assign({}, orig)
        status = "Reverted to the position from when the panel opened."
    }

    // ---------- command queue ----------

    property var queue: []

    function run(args) {
        queue.push(args)
        pump()
    }

    function pump() {
        if (runner.running || queue.length === 0) return
        runner.command = queue.shift()
        runner.running = true
    }

    // ---------- reading Hyprland state ----------

    function parse(text) {
        const parts = text.split("@@\n")
        try {
            const w = JSON.parse(parts[0])
            const all = JSON.parse(parts[1])
            if (!w.address) throw new Error("no window")

            monitors = all.map(m => ({
                name: m.name,
                x: m.x,
                y: m.y,
                w: Math.round(m.width / m.scale),
                h: Math.round(m.height / m.scale)
            }))

            win = { address: w.address, floating: !!w.floating, x: w.at[0], y: w.at[1], w: w.size[0], h: w.size[1], title: w.title || "" }
            orig = Object.assign({}, win)
            status = win.title
        } catch (e) {
            win = null
            orig = null
            monitors = []
            status = "No focused window. Focus a window and reopen."
        }
    }

    onVisibleChanged: {
        if (visible) {
            probe.running = true
            scope.forceActiveFocus()
        }
    }

    Process {
        id: probe
        command: ["sh", "-c", "hyprctl -j activewindow; echo @@; hyprctl -j monitors"]
        stdout: StdioCollector {
            onStreamFinished: tool.parse(this.text)
        }
    }

    Process {
        id: runner
        onRunningChanged: if (!running) tool.pump()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: tool.visible = false
        Keys.onReturnPressed: tool.apply()
        Keys.onEnterPressed: tool.apply()

        MouseArea {
            anchors.fill: parent
            onClicked: tool.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 780
            height: col.implicitHeight + 40
            radius: 12
            color: tool.bg
            border.color: tool.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                spacing: 12

                Text {
                    text: "WINDOW PLACEMENT   drag to move, corner to resize   Enter apply   Esc close"
                    color: tool.muted
                    font.family: tool.font
                    font.pixelSize: 11
                }

                // Preview canvas: monitors to scale, the window on top
                Item {
                    id: canvas
                    width: tool.canvasW
                    height: tool.canvasH
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: tool.surface
                    }

                    Repeater {
                        model: tool.monitors

                        Rectangle {
                            required property var modelData
                            x: tool.toPx(modelData.x)
                            y: tool.toPy(modelData.y)
                            width: modelData.w * tool.s
                            height: modelData.h * tool.s
                            color: "transparent"
                            border.color: tool.muted
                            border.width: 1

                            Text {
                                anchors { left: parent.left; top: parent.top; margins: 6 }
                                text: modelData.name
                                color: tool.muted
                                font.family: tool.font
                                font.pixelSize: 11
                            }
                        }
                    }

                    // The focused window: drag to move
                    Rectangle {
                        visible: tool.win !== null
                        x: tool.win ? tool.toPx(tool.win.x) : 0
                        y: tool.win ? tool.toPy(tool.win.y) : 0
                        width: tool.win ? tool.win.w * tool.s : 0
                        height: tool.win ? tool.win.h * tool.s : 0
                        radius: 6
                        color: Qt.rgba(0.48, 0.64, 0.97, 0.25)
                        border.color: tool.accent
                        border.width: 2

                        Text {
                            anchors { left: parent.left; top: parent.top; margins: 8; right: parent.right }
                            elide: Text.ElideRight
                            text: tool.win ? tool.win.w + " x " + tool.win.h : ""
                            color: tool.fg
                            font.family: tool.font
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.SizeAllCursor
                            property real sx: 0
                            property real sy: 0
                            property real ox: 0
                            property real oy: 0

                            onPressed: (ev) => {
                                const p = mapToItem(canvas, ev.x, ev.y)
                                sx = p.x; sy = p.y
                                ox = tool.win.x; oy = tool.win.y
                            }
                            onPositionChanged: (ev) => {
                                if (!pressed || !tool.win) return
                                const p = mapToItem(canvas, ev.x, ev.y)
                                const w = tool.win.w, h = tool.win.h
                                const nx = ox + (p.x - sx) / tool.s
                                const ny = oy + (p.y - sy) / tool.s
                                tool.setRect(tool.snapTo(nx, tool.candX(w)), tool.snapTo(ny, tool.candY(h)), w, h)
                            }
                        }

                        // Bottom-right corner: resize
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 2 }
                            width: 14
                            height: 14
                            radius: 3
                            color: tool.accent

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeFDiagCursor
                                property real sx: 0
                                property real sy: 0
                                property real ow: 0
                                property real oh: 0

                                onPressed: (ev) => {
                                    const p = mapToItem(canvas, ev.x, ev.y)
                                    sx = p.x; sy = p.y
                                    ow = tool.win.w; oh = tool.win.h
                                }
                                onPositionChanged: (ev) => {
                                    if (!pressed || !tool.win) return
                                    const p = mapToItem(canvas, ev.x, ev.y)
                                    const x = tool.win.x, y = tool.win.y
                                    var nw = Math.max(200, ow + (p.x - sx) / tool.s)
                                    var nh = Math.max(120, oh + (p.y - sy) / tool.s)
                                    const right = tool.snapTo(x + nw, tool.candRight())
                                    const bottom = tool.snapTo(y + nh, tool.candBottom())
                                    nw = Math.max(200, right - x)
                                    nh = Math.max(120, bottom - y)
                                    tool.setRect(x, y, nw, nh)
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tool.status
                    color: tool.muted
                    font.family: tool.font
                    font.pixelSize: 11
                }

                // Presets
                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: tool.presets

                        Rectangle {
                            required property var modelData
                            required property int index
                            height: 28
                            width: lbl.implicitWidth + 20
                            radius: 6
                            color: tool.surface

                            Text {
                                id: lbl
                                anchors.centerIn: parent
                                text: modelData.label
                                color: tool.fg
                                font.family: tool.font
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: tool.applyPreset(index)
                            }
                        }
                    }
                }

                // Actions
                Row {
                    spacing: 6

                    Rectangle {
                        height: 28
                        width: applyTxt.implicitWidth + 24
                        radius: 6
                        color: tool.accent

                        Text {
                            id: applyTxt
                            anchors.centerIn: parent
                            text: "Apply"
                            color: tool.bg
                            font.family: tool.font
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: tool.apply() }
                    }

                    Rectangle {
                        height: 28
                        width: revertTxt.implicitWidth + 24
                        radius: 6
                        color: tool.surface

                        Text {
                            id: revertTxt
                            anchors.centerIn: parent
                            text: "Revert"
                            color: tool.fg
                            font.family: tool.font
                            font.pixelSize: 12
                        }
                        MouseArea { anchors.fill: parent; onClicked: tool.revert() }
                    }

                    Rectangle {
                        height: 28
                        width: closeTxt.implicitWidth + 24
                        radius: 6
                        color: tool.surface

                        Text {
                            id: closeTxt
                            anchors.centerIn: parent
                            text: "Close"
                            color: tool.fg
                            font.family: tool.font
                            font.pixelSize: 12
                        }
                        MouseArea { anchors.fill: parent; onClicked: tool.visible = false }
                    }
                }
            }
        }
    }
}