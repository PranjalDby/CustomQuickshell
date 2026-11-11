import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: bar

    signal launcherRequested()
    signal menuRequested()
    signal wifiRequested()

    anchors { top: true; left: true; right: true }
    implicitHeight: 36
    color: Theme.bg

    property int battery: -1
    property string network: "offline"

    // Real workspaces, sorted. Falls back to showing all numbered ones if the filter finds none.
    readonly property var workspaceList: {
        const all = Hyprland.workspaces.values.filter(w => w.id > 0)
        const shown = all.filter(w => w.id <= 10 || w.active || w.focused || (w.lastIpcObject?.windows ?? 0) > 0)
        return (shown.length > 0 ? shown : all).sort((a, b) => a.id - b.id)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netProc.running = true
            batFile.reload()
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID dev wifi | grep '^yes' | cut -d: -f2"]
        stdout: StdioCollector {
            onStreamFinished: bar.network = this.text.trim() || "offline"
        }
    }

    FileView {
        id: batFile
        path: "/sys/class/power_supply/BAT0/capacity"
        onLoaded: bar.battery = parseInt(text())
        onLoadFailed: bar.battery = -1
    }

    // Left: workspaces
    Row {
        anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
        spacing: 6

        Repeater {
            model: bar.workspaceList

            Pill {
                required property var modelData
                text: modelData.name
                highlighted: modelData.active === true
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
            onClicked: bar.wifiRequested()
        }

        Pill {
            text: System.muted ? "muted" : "vol " + System.volume + "%"
            onClicked: System.toggleMute()
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