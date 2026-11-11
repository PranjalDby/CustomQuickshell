import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: power

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string armed: ""      // action waiting for a second click
    property string pending: ""

    function open() { armed = ""; visible = true }
    function toggle() { visible = !visible }

    // Close the panel first so it isn't in the way, then run the action
    function run(cmd) {
        pending = cmd
        visible = false
        runTimer.restart()
    }

    function choose(id, cmd, needsConfirm) {
        if (needsConfirm && armed !== id) {
            armed = id
            return
        }
        armed = ""
        run(cmd)
    }

    onVisibleChanged: if (visible) scope.forceActiveFocus()

    Timer {
        id: runTimer
        interval: 200
        onTriggered: {
            runner.command = ["sh", "-c", power.pending]
            runner.running = true
        }
    }

    Process { id: runner }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: power.visible = false

        MouseArea {
            anchors.fill: parent
            onClicked: power.visible = false
        }

        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 44; rightMargin: 8 }
            width: 260
            height: body.implicitHeight + 24
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                Text { text: "POWER"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Pill {
                    text: "Lock"
                    width: parent.width
                    onClicked: power.choose("lock", "hyprlock", false)
                }
                Pill {
                    text: "Suspend"
                    width: parent.width
                    onClicked: power.choose("suspend", "systemctl suspend", false)
                }
                Pill {
                    text: "Log out"
                    width: parent.width
                    onClicked: power.choose("logout", "hyprctl dispatch exit", true)
                }
                Pill {
                    text: power.armed === "reboot" ? "Click again to reboot" : "Reboot"
                    width: parent.width
                    highlighted: power.armed === "reboot"
                    onClicked: power.choose("reboot", "systemctl reboot", true)
                }
                Pill {
                    text: power.armed === "shutdown" ? "Click again to shut down" : "Shut down"
                    width: parent.width
                    highlighted: power.armed === "shutdown"
                    onClicked: power.choose("shutdown", "systemctl poweroff", true)
                }

                Text {
                    width: parent.width
                    text: "Esc closes. Log out, reboot, and shut down need a second click."
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                }
            }
        }
    }
}