import Quickshell
import Quickshell.Io
import QtQuick
import "modules"

ShellRoot {
    Bar {
        id: bar
        onLauncherRequested: launcher.visible = !launcher.visible
        onMenuRequested: menu.toggle()
        onWifiRequested: wifiPanel.open()
    }

    Launcher { id: launcher }
    Osd { id: osd }
    Notifications { }

    ThemeSelector { id: themes }
    Display { id: display }
    Wifi { id: wifiPanel }
    Bluetooth { id: btPanel }
    PowerMenu { id: power }
    PluginManager { id: pluginMgr }
    ClipHistory { id: clipboard }

    Scope {
        Repeater {
            model: Plugins.enabled

            Loader {
                required property var modelData
                source: "file://" + modelData.path + "/" + modelData.entry
                onItemChanged: if (item) Plugins.register(modelData.name, item)
            }
        }
    }

    Menu {
        id: menu
        onThemeRequested: themes.open()
        onDisplayRequested: display.visible = true
        onWifiRequested: wifiPanel.open()
        onBluetoothRequested: btPanel.open()
        onPowerRequested: power.open()
        onPluginsRequested: pluginMgr.open()
        onClipboardRequested: clipboard.open()
    }

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
        target: "themes"
        function open(): void { themes.open() }
        function next(): void {
            const i = Theme.names.indexOf(Theme.name)
            Theme.setTheme(Theme.names[(i + 1) % Theme.names.length])
        }
        function set(name: string): void { Theme.setTheme(name) }
    }

    IpcHandler {
        target: "display"
        function toggle(): void { display.toggle() }
    }

    IpcHandler {
        target: "wifi"
        function toggle(): void { wifiPanel.toggle() }
    }

    IpcHandler {
        target: "bluetooth"
        function toggle(): void { btPanel.toggle() }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { power.toggle() }
    }

    IpcHandler {
        target: "plugins"
        function toggle(): void { pluginMgr.toggle() }
    }

    IpcHandler {
        target: "plugin"
        function toggle(name: string): void { Plugins.toggleOpen(name) }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { clipboard.toggle() }
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