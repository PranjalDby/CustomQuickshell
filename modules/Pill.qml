import QtQuick

Rectangle {
    id: pill

    property alias text: label.text
    property bool highlighted: false
    signal clicked()

    implicitWidth: label.implicitWidth + 16
    height: 24
    radius: Theme.radius
    color: highlighted ? Theme.accent : Theme.surface

    Text {
        id: label
        anchors.centerIn: parent
        color: pill.highlighted ? Theme.bg : Theme.fg
        font.family: Theme.font
        font.pixelSize: 12
    }

    MouseArea {
        anchors.fill: parent
        onClicked: pill.clicked()
    }
}