import Quickshell
import QtQuick

PanelWindow {
    id: menuWin

    property var bar: null

    readonly property bool top: bar ? bar.cfg.position !== "bottom" : true
    readonly property real gap: bar ? bar.cfg.height + bar.m + 8 : 52

    visible: bar !== null && bar.menu !== ""
    anchors {
        top: top
        bottom: !top
        right: true
    }
    margins {
        top: top ? gap : 0
        bottom: top ? 0 : gap
        right: bar ? bar.m : 8
    }
    implicitWidth: 300
    implicitHeight: body.implicitHeight + 28
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: bar ? bar.island : "#cc1a1b26"
        border.color: bar ? bar.edge : "#33ffffff"
        border.width: 1

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            // ---------- Network ----------
            Column {
                width: parent.width
                spacing: 8
                visible: menuWin.bar && menuWin.bar.menu === "network"

                Row {
                    width: parent.width
                    Text {
                        width: parent.width - onOff.width
                        text: "WI-FI"
                        color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Chip {
                        id: onOff
                        text: "Turn off"
                        fill: menuWin.bar ? menuWin.bar.cAccent : "#7aa2f7"
                        textColor: menuWin.bar ? menuWin.bar.cBg : "#1a1b26"
                        onClicked: menuWin.bar.setWifi(false)
                    }
                }

                Repeater {
                    model: menuWin.bar ? menuWin.bar.wifiList : []

                    Rectangle {
                        required property var modelData
                        width: body.width
                        height: 30
                        radius: 8
                        color: modelData.active ? Qt.alpha(menuWin.bar.cAccent, 0.25) : Qt.alpha(menuWin.bar.cFg, 0.06)

                        Text {
                            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                            text: (modelData.active ? "● " : "") + modelData.ssid
                            color: menuWin.bar.cFg
                            elide: Text.ElideRight
                            width: parent.width - 60
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            text: modelData.signal + "%"
                            color: menuWin.bar.cFg
                            opacity: 0.6
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menuWin.bar.connectWifi(modelData.ssid)
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: menuWin.bar ? menuWin.bar.wifiMsg : ""
                    wrapMode: Text.Wrap
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    opacity: 0.7
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
            }

            // ---------- Volume ----------
            Column {
                width: parent.width
                spacing: 10
                visible: menuWin.bar && menuWin.bar.menu === "volume"

                Text {
                    text: "VOLUME"
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    opacity: 0.6
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Row {
                    spacing: 8
                    Chip { text: "  −  "; fill: menuWin.bar ? menuWin.bar.cSurface : "#24283b"; textColor: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"; onClicked: menuWin.bar.setVolume("5%-") }
                    Chip { text: menuWin.bar && menuWin.bar.muted ? "Unmute" : "Mute"; fill: menuWin.bar ? menuWin.bar.cSurface : "#24283b"; textColor: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"; onClicked: menuWin.bar.toggleMute() }
                    Chip { text: "  +  "; fill: menuWin.bar ? menuWin.bar.cSurface : "#24283b"; textColor: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"; onClicked: menuWin.bar.setVolume("5%+") }
                }

                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: menuWin.bar ? Qt.alpha(menuWin.bar.cFg, 0.15) : "#33ffffff"
                    Rectangle {
                        width: parent.width * Math.min(menuWin.bar ? menuWin.bar.volume : 0, 100) / 100
                        height: parent.height
                        radius: 4
                        color: menuWin.bar && menuWin.bar.muted ? menuWin.bar.cFg : (menuWin.bar ? menuWin.bar.cAccent : "#7aa2f7")
                        opacity: menuWin.bar && menuWin.bar.muted ? 0.4 : 1.0
                    }
                }

                Text {
                    text: menuWin.bar ? (menuWin.bar.muted ? "Muted" : menuWin.bar.volume + "%") : ""
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                }
            }

            // ---------- Battery ----------
            Column {
                width: parent.width
                spacing: 10
                visible: menuWin.bar && menuWin.bar.menu === "battery"

                Text {
                    text: "BATTERY"
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    opacity: 0.6
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }

                Text {
                    text: menuWin.bar && menuWin.bar.battery >= 0 ? menuWin.bar.battery + "%" : "No battery"
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    font.bold: true
                }

                Text {
                    text: menuWin.bar && menuWin.bar.batStatus !== "" ? menuWin.bar.batStatus : "status unknown"
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    opacity: 0.7
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: menuWin.bar ? Qt.alpha(menuWin.bar.cFg, 0.15) : "#33ffffff"
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(menuWin.bar ? menuWin.bar.battery : 0, 100)) / 100
                        height: parent.height
                        radius: 4
                        color: menuWin.bar && menuWin.bar.battery <= 15 ? menuWin.bar.cRed : (menuWin.bar ? menuWin.bar.cAccent : "#7aa2f7")
                    }
                }
            }

            // ---------- Clock and calendar ----------
            Column {
                width: parent.width
                spacing: 8
                visible: menuWin.bar && menuWin.bar.menu === "clock"

                Text {
                    text: menuWin.bar ? Qt.formatDateTime(menuWin.bar.now, "dddd, d MMMM yyyy") : ""
                    color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.bold: true
                }

                Grid {
                    columns: 7
                    spacing: 4
                    width: parent.width

                    Repeater {
                        model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                        Text {
                            required property string modelData
                            width: (body.width - 24) / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            color: menuWin.bar ? menuWin.bar.cFg : "#c0caf5"
                            opacity: 0.5
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                        }
                    }

                    Repeater {
                        model: menuWin.bar ? menuWin.bar.monthCells(menuWin.bar.now) : []

                        Rectangle {
                            required property int modelData
                            readonly property bool today: modelData > 0 && modelData === (menuWin.bar ? menuWin.bar.now.getDate() : -1)
                            width: (body.width - 24) / 7
                            height: 24
                            radius: 6
                            color: today ? menuWin.bar.cAccent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                visible: modelData > 0
                                text: modelData
                                color: today ? menuWin.bar.cBg : menuWin.bar.cFg
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
    }
}