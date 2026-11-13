import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    WindowTool { id: tool }
    DisplayPanel { id: display }

    IpcHandler {
        target: "windowtool"
        function toggle(): void { tool.toggle() }
    }

    IpcHandler {
        target: "displaypanel"
        function toggle(): void { display.toggle() }
    }
}