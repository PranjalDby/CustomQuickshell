import QtQuick

Rectangle {
    id: chip

    property alias text: label.text
    property string icon: ""
    property color textColor: "#c0caf5"
    property color iconColor: textColor
    property color fill: "transparent"
    property string family: "JetBrainsMono Nerd Font"
    property int size: 12
    signal clicked()

    implicitWidth: content.implicitWidth + 20
    implicitHeight: 28
    radius: 10
    color: fill

    Behavior on color { ColorAnimation { duration: 120 } }

    // Hover and press tint, drawn under the content
    Rectangle {
        anchors.fill: parent
        radius: chip.radius
        color: chip.textColor
        opacity: area.pressed ? 0.16 : (area.containsMouse ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: chip.icon !== ""
            height: chip.implicitHeight
            verticalAlignment: Text.AlignVCenter
            text: chip.icon
            color: chip.iconColor
            font.family: chip.family
            font.pixelSize: chip.size + 2
        }

        Text {
            id: label
            visible: text !== ""
            height: chip.implicitHeight
            verticalAlignment: Text.AlignVCenter
            color: chip.textColor
            font.family: chip.family
            font.pixelSize: chip.size
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}