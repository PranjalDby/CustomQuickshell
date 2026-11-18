import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    Bar { id: bar }
    BarMenu { bar: bar }

    IpcHandler {
        target: "bar"
        function toggle(): void { bar.visible = !bar.visible }
    }
}