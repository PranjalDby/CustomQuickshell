import QtQuick

Rectangle {
    id: island

    property color surface: "#1a1b26"
    property color edge: "#14ffffff"
    default property alias content: slot.data

    implicitHeight: 32
    radius: 12
    color: surface
    border.color: edge
    border.width: 1

    Item {
        id: slot
        anchors.fill: parent
    }
}