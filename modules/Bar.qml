import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: bar

    signal launcherRequested()
    signal menuRequested()

    anchors { top: true; left: true; right: true }
    implicitHeight: 36
    color: Theme.bg

    property int volume: 0
    property bool muted: false
    property int battery: -1
    property string network: "offline"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Poll system status every few seconds
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            volProc.running = true
            netProc.running = true
            batFile.reload()
        }
    }

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = this.text.match(/([\d.]+)/)
                if (m) bar.volume = Math.round(parseFloat(m[1]) * 100)
                bar.muted = this.text.includes("MUTED")
            }
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: bar.network = this.text.trim() || "offline"
        }
    }

    Process { id: muter }

    FileView {
        id: batFile
        path: "/sys/class/power_supply/BAT0/capacity"
        onLoaded: bar.battery = parseInt(batFile.text())
        onLoadFailed: bar.battery = -1
    }

    // Left: workspaces
    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        Repeater {
            model: Hyprland.workspaces

            Pill {
                required property var modelData
                text: modelData.name
                highlighted: modelData.active
                onClicked: modelData.activate()
            }
        }
    }

    // Center: focused window title
    Text {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 420)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: Hyprland.activeToplevel?.title ?? ""
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 13
    }

    // Right: status and launchers
    Row {
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        Pill {
            text: bar.network
            onClicked: netProc.running = true
        }

        Pill {
            text: bar.muted ? "muted" : "vol " + bar.volume + "%"
            onClicked: {
                muter.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
                muter.running = true
            }
        }

        Pill {
            visible: bar.battery >= 0
            text: "bat " + bar.battery + "%"
        }

        Pill {
            text: Qt.formatDateTime(clock.date, "ddd dd MMM  HH:mm")
        }

        Pill {
            text: "Apps"
            highlighted: true
            onClicked: bar.launcherRequested()
        }

        Pill {
            text: "Menu"
            onClicked: bar.menuRequested()
        }
    }
}