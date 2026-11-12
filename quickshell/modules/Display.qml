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

    // The first monitor is the source that others can mirror
    readonly property var monitors: (Hyprland.monitors.values || []).filter(m => m !== null && m !== undefined)
    readonly property var source: monitors.length > 0 ? monitors[0] : null

    function toggle() { visible = !visible }

    function run(cmd) {
        runner.command = ["sh", "-c", cmd]
        runner.running = true
    }

    // Shows the same image on this monitor as on the source
    function mirror(m) {
        if (!source || m.name === source.name) return
        run("hyprctl keyword monitor \"" + m.name + ",preferred,auto," + (m.scale || 1)
            + ",mirror," + source.name + "\"")
    }

    // Gives this monitor its own desktop again
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
                                text: "Mirror " + display.source.name
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