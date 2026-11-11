import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: selector

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    function open() {
        list.currentIndex = Math.max(0, Theme.names.indexOf(Theme.name))
        visible = true
    }

    // apply = true saves the highlighted theme, false reverts to the current one
    function close(apply) {
        if (apply && Theme.names.length > 0) Theme.setTheme(Theme.names[list.currentIndex])
        else Theme.cancelPreview()
        visible = false
    }

    function move(delta) {
        const n = Theme.names.length
        if (n === 0) return
        list.currentIndex = (list.currentIndex + delta + n) % n
        Theme.preview(Theme.names[list.currentIndex])
    }

    onVisibleChanged: if (visible) scope.forceActiveFocus()

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: selector.close(false)
        Keys.onReturnPressed: selector.close(true)
        Keys.onEnterPressed: selector.close(true)
        Keys.onUpPressed: selector.move(-1)
        Keys.onDownPressed: selector.move(1)

        // Click outside the card to cancel
        MouseArea {
            anchors.fill: parent
            onClicked: selector.close(false)
        }

        Rectangle {
            anchors.centerIn: parent
            width: 460
            height: 520
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            // Swallow clicks inside the card
            MouseArea { anchors.fill: parent }

            Column {
                id: column
                anchors { fill: parent; margins: 14 }
                spacing: 10

                Text {
                    id: header
                    text: "THEMES   ↑↓ preview   Enter apply   Esc cancel"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                ListView {
                    id: list
                    width: parent.width
                    height: column.height - header.height - column.spacing
                    clip: true
                    model: Theme.names

                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property var col: Theme.all[modelData] || ({})

                        width: list.width
                        height: 44
                        radius: 6
                        color: list.currentIndex === index ? Theme.surface : "transparent"
                        border.color: modelData === Theme.name ? Theme.accent : "transparent"

                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: modelData + (modelData === Theme.name ? "  (current)" : "")
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 14
                        }

                        Row {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            spacing: 4

                            Repeater {
                                model: ["bg", "accent", "red", "green", "yellow", "fg"]

                                Rectangle {
                                    required property string modelData
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: col[modelData] || "#000000"
                                    border.color: Theme.muted
                                    border.width: 1
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                list.currentIndex = index
                                selector.close(true)
                            }
                        }
                    }
                }
            }
        }
    }
}