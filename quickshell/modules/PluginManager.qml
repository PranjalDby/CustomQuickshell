import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: mgr

    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#66000000"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property int current: 0
    readonly property var list: Plugins.available
    readonly property var currentPlugin: list.length > 0 ? list[current] : null

    function open() { visible = true }
    function toggle() { visible = !visible }

    function move(delta) {
        const n = list.length
        if (n === 0) return
        current = (current + delta + n) % n
    }

    function toggleEnabled(p) {
        if (p) Plugins.setEnabled(p.name, Plugins.enabledNames.indexOf(p.name) < 0)
    }

    function isOn(p) { return p ? Plugins.enabledNames.indexOf(p.name) >= 0 : false }

    onVisibleChanged: {
        if (visible) {
            current = 0
            Plugins.rescan()
            scope.forceActiveFocus()
        }
    }

    FocusScope {
        id: scope
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: mgr.visible = false
        Keys.onUpPressed: mgr.move(-1)
        Keys.onDownPressed: mgr.move(1)
        Keys.onReturnPressed: mgr.toggleEnabled(mgr.currentPlugin)
        Keys.onEnterPressed: mgr.toggleEnabled(mgr.currentPlugin)
        Keys.onSpacePressed: { if (mgr.isOn(mgr.currentPlugin)) Plugins.toggleOpen(mgr.currentPlugin.name) }

        MouseArea {
            anchors.fill: parent
            onClicked: mgr.visible = false
        }

        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: 44; rightMargin: 8 }
            width: 380
            height: body.implicitHeight + 24
            radius: Theme.radius
            color: Theme.bg
            border.color: Theme.accent

            MouseArea { anchors.fill: parent }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 8

                Text { text: "PLUGINS"; color: Theme.muted; font.family: Theme.font; font.pixelSize: 11 }

                Text {
                    visible: mgr.list.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "No plugins found. Add one with scripts/plugin.sh install <git-url>, then press Rescan."
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 12
                }

                Pill { text: "Rescan"; onClicked: Plugins.rescan() }

                ListView {
                    id: rows
                    width: parent.width
                    height: Math.min(contentHeight, 320)
                    clip: true
                    model: mgr.list

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: mgr.isOn(modelData)

                        width: rows.width
                        height: 56
                        radius: 6
                        color: index === mgr.current ? Theme.surface : "transparent"

                        Column {
                            anchors { left: parent.left; leftMargin: 12; right: toggle.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            spacing: 2

                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.title + (modelData.version ? "  v" + modelData.version : "")
                                color: on ? Theme.accent : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 13
                            }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.description
                                color: Theme.muted
                                font.family: Theme.font
                                font.pixelSize: 10
                            }
                        }

                        Pill {
                            id: toggle
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: on ? "On" : "Off"
                            highlighted: on
                            onClicked: {
                                mgr.current = index
                                mgr.toggleEnabled(modelData)
                            }
                        }

                        MouseArea {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: toggle.left }
                            onClicked: mgr.current = index
                        }
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "↑↓ select   Enter enable/disable   Space open   Esc close"
                    color: Theme.muted
                    font.family: Theme.font
                    font.pixelSize: 10
                }
            }
        }
    }
}