import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "airpods"

    StyledText {
        width: parent.width
        text: "AirPods"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Requires the LibrePods daemon running with your AirPods connected. The bridge script is read from this plugin's scripts folder."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "pollInterval"
        label: "Poll interval (seconds)"
        description: "How often the LibrePods bridge is read for battery and mode"
        placeholder: "5"
        defaultValue: "5"
    }
}
