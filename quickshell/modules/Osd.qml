import Quickshell
import QtQuick

PanelWindow {
    id: osd

    visible: false
    anchors { bottom: true }          // a single edge centers the window horizontally
    margins { bottom: 80 }
    implicitWidth: 320
    implicitHeight: 56
    color: "transparent"

    property string label: ""
    property int value: 0

    function show(kind, v) {
        label = kind
        value = v
        visible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bg
        border.color: Theme.accent

        Column {
            anchors { fill: parent; margins: 12 }
            spacing: 8

            Text {
                text: osd.label + "  " + osd.value + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 8
                radius: 4
                color: Theme.surface

                Rectangle {
                    width: parent.width * Math.min(osd.value, 100) / 100
                    height: parent.height
                    radius: 4
                    color: Theme.accent
                }
            }
        }
    }
}