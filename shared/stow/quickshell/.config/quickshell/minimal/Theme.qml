pragma Singleton
import QtQuick

QtObject {
    readonly property color background: "#11111b"
    readonly property color surface: "#1e1e2e"
    readonly property color surfaceRaised: "#313244"
    readonly property color surfaceHover: "#45475a"
    readonly property color foreground: "#cdd6f4"
    readonly property color muted: "#a6adc8"
    readonly property color outline: "#45475a"
    readonly property color accent: "#89b4fa"
    readonly property color accentMuted: "#313b57"
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color danger: "#f38ba8"
    readonly property color scrim: "#99000000"

    readonly property int unit: 4
    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18
    readonly property int radiusPill: 999
    readonly property int fast: 160
    readonly property int normal: 240
}
