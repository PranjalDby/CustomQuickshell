pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string qsDir: Quickshell.env("HOME") + "/.config/quickshell"

    property var names: []          // sorted theme names from themes/
    property var all: ({})          // name -> color map, used for previews and swatches
    property string name: "tokyo-night"
    property bool previewing: false

    readonly property var fallback: ({
        bg: "#1a1b26", surface: "#24283b", fg: "#c0caf5", muted: "#565f89",
        accent: "#7aa2f7", red: "#f7768e", green: "#9ece6a", yellow: "#e0af68"
    })

    property var committed: fallback   // colors actually applied to the system
    property var c: fallback           // colors shown right now (differs while previewing)

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

    function parseEnv(text) {
        const out = {}
        text.split("\n").forEach(line => {
            const i = line.indexOf("=")
            if (i > 0) out[line.slice(0, i).trim()] = line.slice(i + 1).trim()
        })
        return out
    }

    // Apply and save a theme
    function setTheme(n) {
        if (names.indexOf(n) < 0) return
        name = n
        previewing = false
        if (all[n]) {
            committed = Object.assign({}, fallback, all[n])
            c = committed
        }
        applier.command = [root.qsDir + "/scripts/apply-theme.sh", n]
        applier.running = true
    }

    // Show a theme without saving it
    function preview(n) {
        if (!all[n]) return
        previewing = true
        c = Object.assign({}, fallback, all[n])
    }

    // Go back to the applied theme
    function cancelPreview() {
        previewing = false
        c = committed
    }

    // Read every file in themes/ once at startup
    Process {
        id: loader
        command: ["sh", "-c",
            "for f in \"$1\"/*.env; do [ -f \"$f\" ] || continue; echo \"@@ $(basename \"$f\" .env)\"; cat \"$f\"; echo; done",
            "sh", root.qsDir + "/themes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {}
                this.text.split("@@ ").slice(1).forEach(part => {
                    const nl = part.indexOf("\n")
                    if (nl < 0) return
                    map[part.slice(0, nl).trim()] = root.parseEnv(part.slice(nl + 1))
                })
                root.all = map
                root.names = Object.keys(map).sort()
            }
        }
    }

    Process { id: applier }

    FileView {
        id: colorsFile
        path: root.qsDir + "/state/colors.env"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.committed = Object.assign({}, root.fallback, root.parseEnv(text()))
            if (!root.previewing) root.c = root.committed
        }
    }

    FileView {
        id: themeFile
        path: root.qsDir + "/state/theme"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.name = text().trim()
    }

    Component.onCompleted: loader.running = true
}