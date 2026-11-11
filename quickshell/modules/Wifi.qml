import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: wifi

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property bool radioOn: true
    property var networks: []        // [{ ssid, active, signal, secured }]
    property var saved: []           // SSIDs with a saved connection profile
    property string status: ""
    property string askFor: ""       // SSID waiting for a password
    property int current: 0

    readonly property var currentNet: networks.length > 0 ? networks[current] : null

    function open() { visible = true }
    function toggle() { visible = !visible }

    function close() {
        visible = false
        askFor = ""
        pw.text = ""
    }

    function cancelAsk() {
        askFor = ""
        pw.text = ""
        scope.forceActiveFocus()
    }

    function scan() {
        status = "Scanning..."
        scanProc.running = true
    }

    function move(delta) {
        const n = networks.length
        if (n === 0) return
        current = (current + delta + n) % n
    }

    // Start connecting, asking for a password first when needed
    function attempt(net) {
        if (!net || net.active) return
        if (net.secured && saved.indexOf(net.ssid) < 0) {
            askFor = net.ssid
            return
        }
        join(net.ssid, "")
    }

    function join(ssid, pass) {
        status = "Connecting to " + ssid + "..."
        connectProc.command = ["sh", "-c",
            "if [ -n \"$2\" ]; then nmcli dev wifi connect \"$1\" password \"$2\"; "
            + "else nmcli dev wifi connect \"$1\"; fi 2>&1",
            "sh", ssid, pass]
        connectProc.running = true
    }

    function disconnect(ssid) {
        actionProc.command = ["sh", "-c", "nmcli connection down id \"$1\" 2>&1", "sh", ssid]
        actionProc.running = true
    }

    function forget(ssid) {
        actionProc.command = ["sh", "-c", "nmcli connection delete id \"$1\" 2>&1", "sh", ssid]
        actionProc.running = true
    }

    function toggleRadio() {
        actionProc.command = ["sh", "-c", "nmcli radio wifi " + (radioOn ? "off" : "on")]
        actionProc.running = true
    }

    // Output layout: radio state, @@, scan rows, @@, saved profiles
    function parse(text) {
        const parts = text.split("@@\n")
        radioOn = (parts[0] || "").trim() === "enabled"

        const byName = {}
        ;(parts[1] || "").split("\n").forEach(line => {
            if (!line) return
            const f = line.split(":")
            const ssid = f.slice(3).join(":").replace(/\\:/g, ":")
            if (!ssid) return
            const net = {
                ssid: ssid,
                active: f[0] === "*",
                signal: parseInt(f[1]) || 0,
                secured: (f[2] || "").length > 0
            }
            const prev = byName[ssid]
            if (!prev || net.active || net.signal > prev.signal) byName[ssid] = net
        })

        const list = Object.values(byName)
        list.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
        networks = list
        if (current >= list.length) current = 0

        const suffix = ":802-11-wireless"
        saved = (parts[2] || "").split("\n")
            .filter(l => l.endsWith(suffix))
            .map(l => l.slice(0, l.length - suffix.length).replace(/\\:/g, ":"))

        if (!radioOn) status = "Wi-Fi is off"
        else if (list.length === 0) status = "No networks found"
        else status = ""
    }

    onVisibleChanged: {
        if (visible) {
            askFor = ""
            pw.text = ""
            current = 0
            scan()
            scope.forceActiveFocus()
        }
    }

    onAskForChanged: if (askFor !== "") pw.forceActiveFocus()

    Process {
        id: scanProc
        command: ["sh", "-c",
            "nmcli radio wifi; echo @@; "
            + "nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID dev wifi list --rescan auto; echo @@; "
            + "nmcli -t -f NAME,TYPE connection show"]
        stdout: StdioCollector {
            onStreamFinished: wifi.parse(this.text)
        }
    }

    Process {
        id: connectProc
        stdout: StdioCollector {
            onStreamFinished: {
                const out = this.text.trim()
                const ok = out.indexOf("successfully activated") >= 0
                wifi.status = ok ? "Connected" : (out.split("\n").pop() || "Connection failed")
                wifi.askFor = ""
                pw.text = ""
                rescanTimer.restart()
            }
        }
    }

    // Disconnect, forget, and radio toggle. Each one rescans when done.
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: rescanTimer.restart()
        }
    }

    Timer {
        id: rescanTimer
        interval: 1500
        onTriggered: wifi.scan()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (wifi.askFor !== "") wifi.cancelAsk()
            else wifi.close()
        }
        Keys.onUpPressed: wifi.move(-1)
        Keys.onDownPressed: wifi.move(1)
        Keys.onReturnPressed: wifi.attempt(wifi.currentNet)
        Keys.onEnterPressed: wifi.attempt(wifi.currentNet)

        MouseArea {
            anchors.fill: parent
            onClicked: wifi.close()
        }

        Rectangle {
            id: card
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

                Text {
                    text: "WI-FI"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Row {
                    spacing: 6
                    Pill {
                        text: wifi.radioOn ? "Turn off" : "Turn on"
                        onClicked: wifi.toggleRadio()
                    }
                    Pill {
                        text: "Rescan"
                        onClicked: wifi.scan()
                    }
                }

                Text {
                    width: parent.width
                    visible: wifi.status !== ""
                    text: wifi.status
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: list
                    width: parent.width
                    height: 260
                    clip: true
                    model: wifi.networks

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 40
                        radius: 6
                        color: index === wifi.current ? Theme.surface : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            width: parent.width - 80
                            elide: Text.ElideRight
                            text: (modelData.active ? "● " : "") + modelData.ssid
                            color: modelData.active ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        Row {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 8

                            Text {
                                visible: modelData.secured
                                text: "\uf023"              // lock glyph in Nerd Fonts
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                            Text {
                                text: modelData.signal + "%"
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                wifi.current = index
                                wifi.attempt(modelData)
                            }
                        }
                    }
                }

                // Password entry, shown only when a new secured network is selected
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: Theme.surface
                    visible: wifi.askFor !== ""

                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        visible: pw.text.length === 0
                        text: "Password for " + wifi.askFor
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 13
                        Keys.onReturnPressed: (event) => {
                            wifi.join(wifi.askFor, text)
                            event.accepted = true
                        }
                        Keys.onEnterPressed: (event) => {
                            wifi.join(wifi.askFor, text)
                            event.accepted = true
                        }
                        Keys.onEscapePressed: (event) => {
                            wifi.cancelAsk()
                            event.accepted = true
                        }
                    }
                }

                Row {
                    spacing: 6
                    visible: wifi.currentNet !== null

                    Pill {
                        visible: wifi.currentNet !== null && wifi.currentNet.active
                        text: "Disconnect"
                        onClicked: wifi.disconnect(wifi.currentNet.ssid)
                    }
                    Pill {
                        visible: wifi.currentNet !== null && !wifi.currentNet.active
                            && wifi.saved.indexOf(wifi.currentNet.ssid) >= 0
                        text: "Forget"
                        onClicked: wifi.forget(wifi.currentNet.ssid)
                    }
                }

                Text {
                    width: parent.width
                    text: "↑↓ select   Enter connect   Esc close"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
        }
    }
}