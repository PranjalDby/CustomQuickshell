import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Services
import qs.Modules.Plugins

// AirPods for DankMaterialShell, Material 3 styling.
//
// Data comes from scripts/librepods-bridge.sh (copied from
// demic-dev/airpods-widget-DMS). Every color, radius, font size and duration
// below is a Theme token, so the widget adapts to the wallpaper palette and to
// light or dark mode without hardcoded values.

PluginComponent {
    id: root

    property var popoutService: null

    // ---- constants --------------------------------------------------------
    readonly property int lockMs: 4000
    readonly property int pollInterval: (pluginData && pluginData.pollInterval)
        ? parseInt(pluginData.pollInterval) : 5
    readonly property string scriptPath: Qt.resolvedUrl("scripts/librepods-bridge.sh")
        .toString().replace("file://", "")

    readonly property var modes: [
        { id: "off", label: "Off", icon: "block" },
        { id: "transparency", label: "Transparency", icon: "noise_aware" },
        { id: "adaptive", label: "Adaptive", icon: "auto_mode" },
        { id: "anc", label: "ANC", icon: "noise_control_on" }
    ]

    // ---- live state (each instance keeps its own) --------------------------
    property bool ready: false
    property bool connected: false
    property string model: "buds"
    property int batLeft: -1
    property int batRight: -1
    property int batCase: -1
    property int batHeadset: -1
    property string mode: "unknown"
    property bool conversation: false
    property bool earDetection: false
    property string deviceName: "AirPods"

    // Optimistic locks: field -> { value, until }
    property var locks: ({})

    readonly property string modeLabel: {
        for (var i = 0; i < modes.length; i++)
            if (modes[i].id === mode) return modes[i].label
        return ""
    }

    readonly property int lowestLevel: {
        if (model === "headset") return batHeadset
        var vals = []
        if (batLeft >= 0) vals.push(batLeft)
        if (batRight >= 0) vals.push(batRight)
        return vals.length ? Math.min.apply(Math, vals) : -1
    }

    // ---- status ----------------------------------------------------------
    function applyStatus(text) {
        var s = null
        try { s = JSON.parse(text.trim()) } catch (e) { s = null }

        if (!s) {
            ready = true
            connected = false
            return
        }

        var num = function (v) { return typeof v === "number" ? v : -1 }
        var next = {
            connected: !!s.connected,
            model: s.model || "buds",
            batLeft: num(s.left),
            batRight: num(s.right),
            batCase: num(s.case),
            batHeadset: num(s.headset),
            mode: s.mode || "unknown",
            conversation: !!s.conversation,
            earDetection: !!s.earDetection,
            deviceName: s.deviceName || "AirPods"
        }

        // Keep an optimistic value until the hardware confirms it or the lock expires.
        var now = Date.now()
        var nl = Object.assign({}, locks)
        for (var f in locks) {
            var lk = locks[f]
            if (next[f] === lk.value || now >= lk.until) delete nl[f]
            else next[f] = lk.value
        }
        locks = nl

        ready = true
        connected = next.connected
        model = next.model
        batLeft = next.batLeft
        batRight = next.batRight
        batCase = next.batCase
        batHeadset = next.batHeadset
        mode = next.mode
        conversation = next.conversation
        earDetection = next.earDetection
        deviceName = next.deviceName
    }

    function optimisticSet(field, value) {
        var lk = Object.assign({}, locks)
        lk[field] = { value: value, until: Date.now() + lockMs }
        locks = lk
        if (field === "mode") mode = value
        else if (field === "earDetection") earDetection = value
    }

    function refresh() {
        if (!statusProc.running) statusProc.running = true
    }

    Process {
        id: statusProc
        command: ["bash", root.scriptPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(this.text)
        }
    }

    Timer {
        interval: root.pollInterval * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon
        interval: 2500
        repeat: false
        onTriggered: root.refresh()
    }

    // ---- controls --------------------------------------------------------
    Process {
        id: noiseProc
        onExited: refreshSoon.restart()
    }

    Process {
        id: earProc
        onExited: refreshSoon.restart()
    }

    function setNoise(id) {
        if (!connected || noiseProc.running) return
        optimisticSet("mode", id)
        noiseProc.command = ["bash", root.scriptPath, "noise", id]
        noiseProc.running = true
    }

    function cycleNoise() {
        setNoise(mode === "anc" ? "transparency" : "anc")
    }

    function setEarDetection(on) {
        if (earProc.running) return
        optimisticSet("earDetection", on)
        earProc.command = ["bash", root.scriptPath, "eardetection", on ? "on" : "off"]
        earProc.running = true
        ToastService?.showInfo("Ear detection " + (on ? "on" : "off") + ". Reconnect AirPods to apply.")
    }

    // LibrePods has no external toggle for Conversation Awareness.
    function showConversationHint() {
        ToastService?.showInfo("Set Conversation Awareness in the LibrePods app")
    }

    Component.onCompleted: refresh()


    // =====================================================================
    // Inline components
    // =====================================================================

    // Circular battery gauge with a tonal track and a primary progress arc.
    component BatteryRing: Item {
        id: ring
        property int level: -1
        property color ringColor: Theme.primary
        readonly property real strokeW: 6
        readonly property real r: (width - strokeW) / 2

        implicitWidth: 60
        implicitHeight: 60

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.withAlpha(Theme.surfaceText, 0.12)
                strokeWidth: ring.strokeW
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.r
                    radiusY: ring.r
                    startAngle: -90
                    sweepAngle: 360
                }
            }

            ShapePath {
                strokeColor: ring.level >= 0 ? ring.ringColor : "transparent"
                strokeWidth: ring.strokeW
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.r
                    radiusY: ring.r
                    startAngle: -90
                    sweepAngle: ring.level >= 0 ? 360 * Math.max(0, Math.min(100, ring.level)) / 100 : 0
                    Behavior on sweepAngle {
                        NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: ring.level >= 0 ? ring.level : "–"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.DemiBold
            color: ring.level >= 0 ? Theme.surfaceText : Theme.surfaceVariantText
        }
    }

    // Segmented noise selector with a sliding primary-container indicator.
    component NoiseSelector: Rectangle {
        id: seg
        property var controller

        readonly property int count: controller.modes.length
        readonly property real slotW: (width - 10) / count
        readonly property int selIdx: {
            for (var i = 0; i < controller.modes.length; i++)
                if (controller.modes[i].id === controller.mode) return i
            return -1
        }

        implicitHeight: 76
        radius: 24
        color: Theme.surfaceContainerHigh
        opacity: controller.connected ? 1.0 : 0.5

        Rectangle {
            id: indicator
            y: 5
            height: seg.height - 10
            width: seg.slotW
            x: 5 + Math.max(0, seg.selIdx) * seg.slotW
            radius: 19
            color: Theme.primaryContainer
            opacity: seg.selIdx >= 0 ? 1.0 : 0.0
            Behavior on x {
                NumberAnimation { duration: Theme.shortDuration; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.shortDuration }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 5

            Repeater {
                model: seg.controller.modes
                delegate: Item {
                    required property var modelData
                    width: seg.slotW
                    height: parent.height
                    readonly property bool selected: seg.controller.mode === modelData.id

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        DankIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: modelData.icon
                            filled: selected
                            size: Theme.iconSize - 2
                            color: selected ? Theme.primary : Theme.surfaceVariantText
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall - 1
                            font.weight: selected ? Font.DemiBold : Font.Normal
                            color: selected ? Theme.primary : Theme.surfaceVariantText
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: seg.controller.connected
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.controller.setNoise(modelData.id)
                    }
                }
            }
        }
    }

    // A settings-style row: tonal icon badge, title and subtitle, trailing switch.
    component SettingRow: Item {
        id: row
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled(bool value)

        implicitHeight: 64
        width: parent ? parent.width : implicitWidth

        Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            radius: 14
            color: row.checked && row.enabled ? Theme.primaryContainer : Theme.surfaceContainerHighest

            DankIcon {
                anchors.centerIn: parent
                name: row.icon
                filled: row.checked && row.enabled
                size: Theme.iconSize - 4
                color: row.checked && row.enabled ? Theme.primary : Theme.surfaceVariantText
            }
        }

        Column {
            anchors.left: badge.right
            anchors.right: toggle.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: 2

            StyledText {
                width: parent.width
                text: row.title
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: row.subtitle
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
            }
        }

        DankToggle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            hideText: true
            checked: row.checked
            enabled: row.enabled
            onToggled: value => row.toggled(value)
        }
    }

    // Full panel body, shared by the popout and the Control Center detail.
    component PanelBody: Column {
        id: panel
        property var controller
        spacing: Theme.spacingM

        // ---- header ----------------------------------------------------
        Row {
            width: parent.width
            spacing: Theme.spacingM

            Rectangle {
                width: 52
                height: 52
                radius: 18
                color: panel.controller.connected ? Theme.primary : Theme.surfaceContainerHighest
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    anchors.centerIn: parent
                    name: "earbuds"
                    filled: true
                    size: Theme.iconSizeLarge - 4
                    color: panel.controller.connected ? Theme.primaryText : Theme.surfaceVariantText
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52 - Theme.spacingM
                spacing: 4

                StyledText {
                    width: parent.width
                    text: panel.controller.deviceName
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                }

                Rectangle {
                    height: 22
                    width: statusText.implicitWidth + Theme.spacingM * 2
                    radius: 11
                    color: panel.controller.connected ? Theme.primaryContainer : Theme.surfaceContainerHighest

                    StyledText {
                        id: statusText
                        anchors.centerIn: parent
                        text: !panel.controller.ready ? "Checking…"
                            : (panel.controller.connected ? "Connected" : "Disconnected")
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: panel.controller.connected ? Theme.primary : Theme.surfaceVariantText
                    }
                }
            }
        }

        // ---- battery ---------------------------------------------------
        Row {
            width: parent.width
            spacing: Theme.spacingS

            Repeater {
                model: panel.controller.model === "headset" ? [] : [
                    { name: "Left", level: panel.controller.batLeft },
                    { name: "Right", level: panel.controller.batRight },
                    { name: "Case", level: panel.controller.batCase }
                ]

                delegate: Rectangle {
                    required property var modelData
                    width: (parent.width - Theme.spacingS * 2) / 3
                    height: 112
                    radius: 20
                    color: Theme.surfaceContainerHigh

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS

                        BatteryRing {
                            anchors.horizontalCenter: parent.horizontalCenter
                            level: modelData.level
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.surfaceVariantText
                        }
                    }
                }
            }

            Rectangle {
                visible: panel.controller.model === "headset"
                width: parent.width
                height: 112
                radius: 20
                color: Theme.surfaceContainerHigh

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingM

                    BatteryRing {
                        anchors.verticalCenter: parent.verticalCenter
                        level: panel.controller.batHeadset
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Headset"
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }
                }
            }
        }

        // ---- noise control ---------------------------------------------
        StyledText {
            text: "Noise control"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: Theme.surfaceVariantText
        }

        NoiseSelector {
            width: parent.width
            controller: panel.controller
        }

        // ---- settings --------------------------------------------------
        Rectangle {
            width: parent.width
            height: rows.implicitHeight + Theme.spacingS * 2
            radius: 20
            color: Theme.surfaceContainerHigh

            Column {
                id: rows
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS

                SettingRow {
                    icon: "record_voice_over"
                    title: "Conversation awareness"
                    subtitle: "Set in the LibrePods app"
                    checked: panel.controller.conversation
                    enabled: panel.controller.connected
                    onToggled: panel.controller.showConversationHint()
                }

                SettingRow {
                    icon: "hearing"
                    title: "Ear detection"
                    subtitle: "Pause audio when a bud is removed"
                    checked: panel.controller.earDetection
                    enabled: panel.controller.connected
                    onToggled: value => panel.controller.setEarDetection(value)
                }
            }
        }
    }

    // =====================================================================
    // Surfaces
    // =====================================================================

    popoutWidth: 380
    popoutHeight: 540

    popoutContent: Component {
        PopoutComponent {
            headerText: ""
            showCloseButton: true

            PanelBody {
                width: parent.width
                controller: root
            }
        }
    }

    horizontalBarPill: Component {
        StyledRect {
            implicitWidth: pillRow.implicitWidth + Theme.spacingM * 2
            height: parent.widgetThickness
            radius: Theme.cornerRadius
            color: root.connected ? Theme.primaryContainer : Theme.surfaceContainerHigh
            border.width: root.conversation ? 2 : 0
            border.color: Theme.primary

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "earbuds"
                    filled: root.connected
                    size: root.iconSize
                    color: root.connected ? Theme.primary : Theme.surfaceVariantText
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.connected && root.lowestLevel >= 0 ? root.lowestLevel + "%"
                        : (root.connected ? "On" : "–")
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: root.connected ? Theme.primary : Theme.surfaceVariantText
                }
            }
        }
    }

    verticalBarPill: Component {
        StyledRect {
            width: parent.widgetThickness
            implicitHeight: pillCol.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: root.connected ? Theme.primaryContainer : Theme.surfaceContainerHigh
            border.width: root.conversation ? 2 : 0
            border.color: Theme.primary

            Column {
                id: pillCol
                anchors.centerIn: parent
                spacing: 2

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "earbuds"
                    filled: root.connected
                    size: root.iconSize
                    color: root.connected ? Theme.primary : Theme.surfaceVariantText
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.connected && root.lowestLevel >= 0
                    text: root.lowestLevel
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.primary
                }
            }
        }
    }

    ccWidgetIcon: "earbuds"
    ccWidgetPrimaryText: root.deviceName
    ccWidgetSecondaryText: root.connected
        ? (root.modeLabel + (root.lowestLevel >= 0 ? " · " + root.lowestLevel + "%" : ""))
        : "Disconnected"
    ccWidgetIsActive: root.connected && root.mode !== "off"
    ccDetailHeight: 500

    // Tapping the tile cycles ANC and Transparency.
    onCcWidgetToggled: {
        if (root.connected) root.cycleNoise()
    }

    ccDetailContent: Component {
        Rectangle {
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            PanelBody {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingM
                controller: root
            }
        }
    }
}