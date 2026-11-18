import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    Bar { id: bar }

    IpcHandler {
        target: "bar"
        function toggle(): void { bar.visible = !bar.visible }
    }
}