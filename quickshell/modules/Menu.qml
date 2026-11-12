import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: menu

    signal themeRequested()
    signal displayRequested()
    signal wifiRequested()
    signal bluetoothRequested()
    signal powerRequested()
    signal pluginsRequested()
    signal clipboardRequested()

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string pending: ""

    function toggle() { visible = !visible }

    // Close first, then run the command after a delay so screenshots don't capture the menu
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

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10

                Text { text: "APPEARANCE"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Flow {
                    width: parent.width
                    spacing: 6
                    Pill {
                        text: "Themes"
                        highlighted: true
                        onClicked: { menu.visible = false; menu.themeRequested() }
                    }
                    Pill {
                        text: "Displays"
                        onClicked: { menu.visible = false; menu.displayRequested() }
                    }
                }

                Text { text: "NETWORK & POWER"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Flow {
                    width: parent.width
                    spacing: 6
                    Pill { text: "Wi-Fi"; onClicked: { menu.visible = false; menu.wifiRequested() } }
                    Pill { text: "Bluetooth"; onClicked: { menu.visible = false; menu.bluetoothRequested() } }
                    Pill { text: "Power"; onClicked: { menu.visible = false; menu.powerRequested() } }
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
                    Pill { text: "Logout"; onClicked: menu.run("~/.config/quickshell/scripts/logout.sh") }
                    Pill { text: "Clipboard"; onClicked: { menu.visible = false; menu.clipboardRequested() } }
                    Pill { text: "Plugins"; onClicked: { menu.visible = false; menu.pluginsRequested() } }
                }
            }
        }
    }
}