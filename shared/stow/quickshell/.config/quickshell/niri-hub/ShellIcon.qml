import QtQuick
import Quickshell
import "."

IconImage {
    id: root

    property int iconSize: 22
    property string text: ""
    property string fallback: "image-missing-symbolic"
    Accessible.ignored: true
    implicitSize: Math.round(iconSize * Theme.scale)
    source: Quickshell.iconPath(root.iconName(root.text), root.fallback)

    function iconName(name): string {
        const icons = {
            "arrow_back": "go-previous-symbolic",
            "bedtime": "system-suspend-symbolic",
            "bluetooth": "bluetooth-active-symbolic",
            "bluetooth_connected": "bluetooth-active-symbolic",
            "bluetooth_disabled": "bluetooth-disabled-symbolic",
            "bolt": "battery-level-100-charging-symbolic",
            "power_settings_new": "system-shutdown-symbolic",
            "restart_alt": "system-reboot-symbolic",
            "search": "system-search-symbolic",
            "wifi": "network-wireless-symbolic",
            "wifi_off": "network-wireless-disabled-symbolic",
            "network_wifi": "network-wireless-symbolic"
        }
        return icons[name] || name
    }
}
