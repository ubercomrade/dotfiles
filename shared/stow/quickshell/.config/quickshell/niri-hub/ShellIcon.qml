import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "."

Item {
    id: root

    property int iconSize: 22
    property string text: ""
    property string fallback: "image-missing-symbolic"
    property color color: Theme.foreground
    Accessible.ignored: true
    implicitWidth: Math.round(iconSize * Theme.scale)
    implicitHeight: implicitWidth

    IconImage {
        id: image
        anchors.fill: parent
        source: Quickshell.iconPath(root.iconName(root.text), root.fallback)
        visible: false
    }

    ColorOverlay {
        anchors.fill: parent
        source: image
        color: root.color
    }

    function iconName(name): string {
        const icons = {
            "arrow_back": "go-previous-symbolic",
            "bedtime": "weather-clear-night-symbolic",
            "bluetooth": "bluetooth-active-symbolic",
            "bluetooth_connected": "bluetooth-active-symbolic",
            "bluetooth_disabled": "bluetooth-disabled-symbolic",
            "bolt": "battery-level-90-charging-symbolic",
            "power_settings_new": "system-shutdown-symbolic",
            "restart_alt": "view-refresh-symbolic",
            "search": "system-search-symbolic",
            "shield_lock": "dialog-password-symbolic",
            "lock_open": "system-lock-screen-symbolic",
            "wifi": "network-wireless-symbolic",
            "wifi_off": "network-wireless-disabled-symbolic",
            "network_wifi": "network-wireless-symbolic"
        }
        return icons[name] || name
    }
}
