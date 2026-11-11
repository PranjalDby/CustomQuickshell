pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string qsDir: Quickshell.env("HOME") + "/.config/quickshell"
    readonly property string pluginDir: qsDir + "/plugins"
    readonly property string stateDir: qsDir + "/state"
    readonly property string stateFile: stateDir + "/plugins.txt"

    property var available: []
    property var enabledNames: []
    readonly property var enabled: available.filter(p => enabledNames.indexOf(p.name) >= 0)

    property var loaded: ({})

    function register(name, item) {
        const m = Object.assign({}, loaded)
        m[name] = item
        loaded = m
    }

    function unregister(name) {
        const m = Object.assign({}, loaded)
        delete m[name]
        loaded = m
    }

    function toggleOpen(name) {
        const it = loaded[name]
        if (it) it.visible = !it.visible
    }

    function rescan() { scanner.running = true }

    function setEnabled(name, on) {
        const next = enabledNames.filter(n => n !== name)
        if (on) next.push(name)
        else unregister(name)
        enabledNames = next
        writer.command = ["sh", "-c",
            "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"",
            "sh", stateDir, next.join("\n") + "\n", stateFile]
        writer.running = true
    }

    Process {
        id: scanner
        command: ["sh", "-c",
            "for d in \"$1\"/*/; do f=\"$d/plugin.json\"; [ -f \"$f\" ] || continue; "
            + "echo \"@@ $(basename \"$d\")\"; cat \"$f\"; echo; done",
            "sh", root.pluginDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                this.text.split("@@ ").slice(1).forEach(part => {
                    const nl = part.indexOf("\n")
                    if (nl < 0) return
                    const folder = part.slice(0, nl).trim()
                    try {
                        const m = JSON.parse(part.slice(nl + 1))
                        list.push({
                            name: folder,
                            title: m.name || folder,
                            description: m.description || "",
                            version: m.version || "",
                            entry: m.entry || "Panel.qml",
                            path: root.pluginDir + "/" + folder
                        })
                    } catch (e) {
                        console.warn("Plugins: bad plugin.json in", folder)
                    }
                })
                root.available = list.sort((a, b) => a.name.localeCompare(b.name))
            }
        }
    }

    Process { id: writer }

    FileView {
        id: stateView
        path: root.stateFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.enabledNames = text().split("\n").map(s => s.trim()).filter(s => s.length > 0)
        onLoadFailed: root.enabledNames = []
    }

    Component.onCompleted: rescan()
}