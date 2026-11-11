pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property int brightness: 0
    property int volume: 0
    property bool muted: false

    // Emitted only after the user changes something, so the OSD doesn't pop up on polling
    signal osdRequested(string kind, int value)

    function setBrightness(arg) {
        brightSet.command = ["sh", "-c",
            "brightnessctl -q set \"$1\"; brightnessctl -m | cut -d, -f4 | tr -d %", "sh", arg]
        brightSet.running = true
    }

    function setVolume(arg) {
        volSet.command = ["sh", "-c",
            "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ \"$1\"; wpctl get-volume @DEFAULT_AUDIO_SINK@", "sh", arg]
        volSet.running = true
    }

    function toggleMute() {
        volSet.command = ["sh", "-c",
            "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle; wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        volSet.running = true
    }

    function readVolume(t) {
        const m = t.match(/([\d.]+)/)
        if (m) root.volume = Math.round(parseFloat(m[1]) * 100)
        root.muted = t.includes("MUTED")
    }

    function refresh() {
        brightRead.running = true
        volRead.running = true
    }

    Process {
        id: brightSet
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text)
                if (!isNaN(v)) {
                    root.brightness = v
                    root.osdRequested("Brightness", v)
                }
            }
        }
    }

    Process {
        id: volSet
        stdout: StdioCollector {
            onStreamFinished: {
                root.readVolume(this.text)
                root.osdRequested(root.muted ? "Muted" : "Volume", root.volume)
            }
        }
    }

    // Silent reads, used at startup and by the poll timer
    Process {
        id: brightRead
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d %"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text)
                if (!isNaN(v)) root.brightness = v
            }
        }
    }

    Process {
        id: volRead
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: root.readVolume(this.text)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}