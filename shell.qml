import Quickshell
import Quickshell.Io
import QtQuick
import "modules"

ShellRoot {
    Bar {
        id: bar
        onLauncherRequested: launcher.visible = !launcher.visible
        onMenuRequested: menu.toggle()
    }

    Launcher { id: launcher }
    Menu { id: menu }
    Osd { id: osd }
    Notifications { }

    Connections {
        target: System
        function onOsdRequested(kind, value) { osd.show(kind, value) }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.visible = !launcher.visible }
    }

    IpcHandler {
        target: "menu"
        function toggle(): void { menu.toggle() }
    }

    IpcHandler {
        target: "theme"
        function next(): void {
            const i = Theme.names.indexOf(Theme.name)
            Theme.setTheme(Theme.names[(i + 1) % Theme.names.length])
        }
        function set(name: string): void { Theme.setTheme(name) }
    }

    IpcHandler {
        target: "brightness"
        function up(): void { System.setBrightness("5%+") }
        function down(): void { System.setBrightness("5%-") }
    }

    IpcHandler {
        target: "volume"
        function up(): void { System.setVolume("5%+") }
        function down(): void { System.setVolume("5%-") }
        function mute(): void { System.toggleMute() }
    }
}