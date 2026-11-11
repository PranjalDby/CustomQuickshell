import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: menu

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string pending: ""

    function toggle() { visible = !visible }

    // Close the menu first, then run the command after a short delay,
    // so screenshots and other tools don't capture the menu
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

        // Click outside the card to close
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

            // Swallow clicks inside the card
            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                Text { text: "THEME"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: Theme.names
                        Pill {
                            required property string modelData
                            text: modelData
                            highlighted: modelData === Theme.name
                            onClicked: Theme.setTheme(modelData)
                        }
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