import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: bt

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool powered: false
    property var devices: []          // [{ mac, name, connected }]
    property string status: ""
    property int current: 0

    readonly property var currentDev: devices.length > 0 ? devices[current] : null

    // Output: power state, @@, all devices, @@, connected devices
    readonly property string refreshCmd:
        "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off; echo @@; "
        + "bluetoothctl devices; echo @@; bluetoothctl devices Connected"

    function open() { visible = true }
    function toggle() { visible = !visible }

    function refresh() {
        reader.command = ["sh", "-c", refreshCmd]
        reader.running = true
    }

    function scan() {
        status = "Scanning for 8 seconds..."
        reader.command = ["sh", "-c",
            "timeout 8 bluetoothctl scan on >/dev/null 2>&1; bluetoothctl scan off >/dev/null 2>&1; " + refreshCmd]
        reader.running = true
    }

    function togglePower() {
        run("bluetoothctl power " + (powered ? "off" : "on"), powered ? "Turning off..." : "Turning on...")
    }

    function run(cmd, msg) {
        status = msg
        actor.command = ["sh", "-c", cmd + " 2>&1"]
        actor.running = true
    }

    function act(dev) {
        if (!dev) return
        if (dev.connected) run("bluetoothctl disconnect " + dev.mac, "Disconnecting " + dev.name + "...")
        else run("bluetoothctl connect " + dev.mac, "Connecting to " + dev.name + "...")
    }

    function forget(dev) {
        if (dev) run("bluetoothctl remove " + dev.mac, "Removed " + dev.name)
    }

    function move(delta) {
        const n = devices.length
        if (n === 0) return
        current = (current + delta + n) % n
    }

    function parse(text) {
        const p = text.split("@@\n")
        powered = (p[0] || "").trim() === "on"

        const connected = {}
        ;(p[2] || "").split("\n").forEach(l => {
            const m = l.trim().split(" ")
            if (m[1]) connected[m[1]] = true
        })

        devices = (p[1] || "").split("\n")
            .filter(l => l.startsWith("Device "))
            .map(l => {
                const parts = l.trim().split(" ")
                return {
                    mac: parts[1],
                    name: parts.slice(2).join(" ") || parts[1],
                    connected: !!connected[parts[1]]
                }
            })
            .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))

        if (current >= devices.length) current = 0

        if (!powered) status = "Bluetooth is off"
        else if (devices.length === 0) status = "No devices. Press Scan to find nearby ones."
        else if (status.indexOf("Scanning") === 0) status = ""
    }

    onVisibleChanged: {
        if (visible) {
            current = 0
            refresh()
            scope.forceActiveFocus()
        }
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: bt.parse(this.text)
        }
    }

    // Runs pair, connect, disconnect, power, and remove. Reloads the list when done.
    Process {
        id: actor
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim().split("\n").pop()
                if (out) bt.status = out
                rescanTimer.restart()
            }
        }
    }

    Timer {
        id: rescanTimer
        interval: 1500
        onTriggered: bt.refresh()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: bt.visible = false
        Keys.onUpPressed: bt.move(-1)
        Keys.onDownPressed: bt.move(1)
        Keys.onReturnPressed: bt.act(bt.currentDev)
        Keys.onEnterPressed: bt.act(bt.currentDev)

        MouseArea {
            anchors.fill: parent
            onClicked: bt.visible = false
        }

        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 44; rightMargin: 8 }
            width: 340
            height: body.implicitHeight + 24
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                Text { text: "BLUETOOTH"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Row {
                    spacing: 6
                    Pill { text: bt.powered ? "Turn off" : "Turn on"; onClicked: bt.togglePower() }
                    Pill { text: "Scan"; visible: bt.powered; onClicked: bt.scan() }
                    Pill { text: "Forget"; visible: bt.powered && bt.currentDev !== null; onClicked: bt.forget(bt.currentDev) }
                }

                Text {
                    width: parent.width
                    visible: bt.status !== ""
                    text: bt.status
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: list
                    width: parent.width
                    height: 240
                    clip: true
                    model: bt.devices

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 40
                        radius: 6
                        color: index === bt.current ? Theme.surface : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: parent.width - 100
                            elide: Text.ElideRight
                            text: (modelData.connected ? "● " : "") + modelData.name
                            color: modelData.connected ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        Text {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: modelData.connected ? "connected" : "paired"
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                bt.current = index
                                bt.act(modelData)
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "↑↓ select   Enter connect/disconnect   Esc close"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
        }
    }
}