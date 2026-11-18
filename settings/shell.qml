import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    SettingsPanel { id: settings }

    IpcHandler {
        target: "settings"
        function toggle(): void { settings.toggle() }
    }
}