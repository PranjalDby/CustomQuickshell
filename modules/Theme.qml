pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string qsDir: Quickshell.env("HOME") + "/.config/quickshell"

    property var names: []
    property string name: "tokyo-night"

    // Fallback colors, used until state/colors.env loads
    property var c: ({
        bg: "#1a1b26", surface: "#24283b", fg: "#c0caf5", muted: "#565f89",
        accent: "#7aa2f7", red: "#f7768e", green: "#9ece6a", yellow: "#e0af68"
    })

    readonly property color bg: c.bg
    readonly property color surface: c.surface
    readonly property color fg: c.fg
    readonly property color muted: c.muted
    readonly property color accent: c.accent
    readonly property color red: c.red
    readonly property color green: c.green
    readonly property color yellow: c.yellow

    readonly property int radius: 8
    readonly property string font: "JetBrainsMono Nerd Font"

    function setTheme(n) {
        if (names.indexOf(n) < 0) return
        name = n
        applier.command = [root.qsDir + "/scripts/apply-theme.sh", n]
        applier.running = true
    }

    function parseEnv(text) {
        const out = {}
        text.split("\n").forEach(line => {
            const i = line.indexOf("=")
            if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim()
        })
        return out
    }

    // Theme list comes from the files in themes/
    Process {
        id: lister
        command: ["sh", "-c", "ls \"$1\" | sed -n 's/\\.env$//p'", "sh", root.qsDir + "/themes"]
        stdout: StdioCollector {
            onStreamFinished: root.names = this.text.trim().split("\n").filter(s => s.length > 0).sort()
        }
    }

    Process { id: applier }

    FileView {
        id: colorsFile
        path: root.qsDir + "/state/colors.env"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.c = Object.assign({}, root.c, root.parseEnv(text()))
    }

    FileView {
        id: themeFile
        path: root.qsDir + "/state/theme"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.name = text().trim()
    }

    Component.onCompleted: lister.running = true
}