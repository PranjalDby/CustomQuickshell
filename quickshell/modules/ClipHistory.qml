import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: clip

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property var entries: []     // [{ raw, text }], newest first
    property var shown: []
    property int current: 0

    function open() { visible = true }
    function toggle() { visible = !visible }

    function reload() { lister.running = true }

    function applyFilter() {
        const q = query.text.toLowerCase()
        shown = entries.filter(e => e.text.toLowerCase().indexOf(q) >= 0).slice(0, 60)
        current = 0
    }

    function move(delta) {
        const n = shown.length
        if (n === 0) return
        current = (current + delta + n) % n
    }

    function copy(e) {
        if (!e) return
        runner.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", e.raw]
        runner.running = true
        visible = false
    }

    function remove(e) {
        if (!e) return
        runner.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", e.raw]
        runner.running = true
        reloadTimer.restart()
    }

    function wipe() {
        runner.command = ["sh", "-c", "cliphist wipe"]
        runner.running = true
        reloadTimer.restart()
    }

    onVisibleChanged: {
        if (visible) {
            query.text = ""
            reload()
            query.forceActiveFocus()
        }
    }

    Process {
        id: lister
        command: ["sh", "-c", "cliphist list"]
        stdout: StdioCollector {
            onStreamFinished: {
                clip.entries = this.text.split("\n")
                    .filter(l => l.length > 0)
                    .map(l => {
                        const tab = l.indexOf("\t")
                        const preview = tab >= 0 ? l.slice(tab + 1) : l
                        return { raw: l, text: preview.replace(/\s+/g, " ").trim() }
                    })
                clip.applyFilter()
            }
        }
    }

    Process { id: runner }

    Timer {
        id: reloadTimer
        interval: 300
        onTriggered: clip.reload()
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: clip.visible = false
        Keys.onUpPressed: clip.move(-1)
        Keys.onDownPressed: clip.move(1)
        Keys.onReturnPressed: clip.copy(clip.shown[clip.current])
        Keys.onEnterPressed: clip.copy(clip.shown[clip.current])
        Keys.onDeletePressed: clip.remove(clip.shown[clip.current])

        MouseArea {
            anchors.fill: parent
            onClicked: clip.visible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: 460
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                anchors { fill: parent; margins: 14 }
                spacing: 10

                Text {
                    text: "CLIPBOARD   Enter copy   Del remove   Esc close"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 6
                    color: Theme.surface

                    TextInput {
                        id: query
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 13
                        onTextChanged: clip.applyFilter()
                        Keys.onEscapePressed: clip.visible = false
                        Keys.onUpPressed: clip.move(-1)
                        Keys.onDownPressed: clip.move(1)
                        Keys.onReturnPressed: clip.copy(clip.shown[clip.current])
                        Keys.onEnterPressed: clip.copy(clip.shown[clip.current])
                    }
                }

                ListView {
                    id: list
                    width: parent.width
                    height: parent.height - 34 - 10 - 16 - 10 - 26
                    clip: true
                    model: clip.shown
                    currentIndex: clip.current

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 34
                        radius: 6
                        color: index === clip.current ? Theme.surface : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: 10; right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideRight
                            text: modelData.text
                            color: index === clip.current ? Theme.accent : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 13
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                clip.current = index
                                clip.copy(modelData)
                            }
                        }
                    }
                }

                Row {
                    spacing: 6

                    Pill {
                        text: "Clear all"
                        onClicked: clip.wipe()
                    }
                    Text {
                        text: clip.shown.length + " of " + clip.entries.length
                        color: Theme.muted
                        font.family: Theme.font
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}