import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: launcher

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#99000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string query: ""

    readonly property var results: {
        const q = query.toLowerCase()
        return DesktopEntries.applications.values
            .filter(a => !a.noDisplay && a.name.toLowerCase().includes(q))
            .slice(0, 40)
    }

    onVisibleChanged: {
        if (visible) {
            input.text = ""
            input.forceActiveFocus()
        }
    }

    function launch(entry) {
        entry.execute()
        launcher.visible = false
    }

    // Click outside the panel to close
    MouseArea {
        anchors.fill: parent
        onClicked: launcher.visible = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.2
        width: 520
        height: 440
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.accent

        // Swallow clicks so the panel doesn't close
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            TextInput {
                id: input
                width: parent.width
                focus: true
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 16
                onTextChanged: {
                    launcher.query = text
                    list.currentIndex = 0
                }
                Keys.onEscapePressed: launcher.visible = false
                Keys.onReturnPressed: {
                    if (launcher.results.length > 0) launcher.launch(launcher.results[list.currentIndex])
                }
                Keys.onDownPressed: list.incrementCurrentIndex()
                Keys.onUpPressed: list.decrementCurrentIndex()
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - input.height - 8
                clip: true
                model: launcher.results

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 36
                    radius: 6
                    color: list.currentIndex === index ? Theme.accent : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: modelData.name
                        color: list.currentIndex === index ? Theme.bg : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: launcher.launch(modelData)
                    }
                }
            }
        }
    }
}