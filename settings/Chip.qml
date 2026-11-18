import QtQuick

Rectangle {
    id: chip

    property alias text: label.text
    property color textColor: "#c0caf5"
    property color fill: "#24283b"
    property string family: "JetBrainsMono Nerd Font"
    property int size: 12
    signal clicked()

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 24
    radius: 6
    color: fill

    Text {
        id: label
        anchors.centerIn: parent
        color: chip.textColor
        font.family: chip.family
        font.pixelSize: chip.size
    }

    MouseArea {
        anchors.fill: parent
        onClicked: chip.clicked()
    }
}