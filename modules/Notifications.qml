import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Scope {
    id: root

    property int counter: 0
    ListModel { id: items }

    NotificationServer {
        id: server
        bodySupported: true
        onNotification: notification => {
            notification.tracked = true
            root.counter += 1
            items.insert(0, {
                uid: root.counter,
                summary: notification.summary,
                body: notification.body,
                app: notification.appName
            })
            if (items.count > 5) items.remove(5)
        }
    }

    function remove(uid) {
        for (let i = 0; i < items.count; i++) {
            if (items.get(i).uid === uid) {
                items.remove(i)
                return
            }
        }
    }

    PanelWindow {
        visible: items.count > 0
        anchors { top: true; right: true }
        margins { top: 44; right: 8 }
        implicitWidth: 320
        implicitHeight: col.implicitHeight
        color: "transparent"

        Column {
            id: col
            width: parent.width
            spacing: 8

            Repeater {
                model: items

                delegate: Rectangle {
                    required property int uid
                    required property string summary
                    required property string body
                    required property string app

                    width: 320
                    height: content.implicitHeight + 16
                    radius: Theme.radius
                    color: Theme.surface
                    border.color: Theme.accent

                    Column {
                        id: content
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        spacing: 4

                        Text {
                            text: app
                            color: Theme.muted
                            font.family: Theme.font
                            font.pixelSize: 10
                        }
                        Text {
                            width: parent.width
                            text: summary
                            color: Theme.fg
                            font.family: Theme.font
                            font.bold: true
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }
                        Text {
                            width: parent.width
                            visible: body.length > 0
                            text: body
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.remove(uid)
                    }

                    Timer {
                        interval: 6000
                        running: true
                        onTriggered: root.remove(uid)
                    }
                }
            }
        }
    }
}