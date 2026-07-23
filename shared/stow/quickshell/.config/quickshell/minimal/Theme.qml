pragma Singleton
import QtQuick
import "."

QtObject {
    id: root

    readonly property color background: "#0b1020"
    readonly property color surface: "#121a2b"
    readonly property color surfaceRaised: "#19243a"
    readonly property color surfaceHover: "#223250"
    readonly property color surfaceHighest: "#2b3b5d"
    readonly property color foreground: "#e7ecff"
    readonly property color muted: "#9ba9c8"
    readonly property color disabled: "#687693"
    readonly property color outline: "#334563"
    readonly property color separator: "#263650"
    readonly property color accent: ShellSettings.accentColor
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color accentForeground: "#07111f"
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color danger: "#f38ba8"
    readonly property color scrim: "#b30a0e19"

    readonly property real scale: ShellSettings.interfaceScale
    readonly property int unit: Math.round(4 * scale)
    readonly property int radiusSmall: Math.round(8 * scale)
    readonly property int radiusMedium: Math.round(13 * scale)
    readonly property int radiusLarge: Math.round(20 * scale)
    readonly property int radiusPill: 999
    readonly property int controlHeight: Math.round(44 * scale)
    readonly property int rowHeight: Math.round(58 * scale)
    readonly property int cardHeight: Math.round(80 * scale)
    readonly property int iconButtonSize: Math.round(44 * scale)
    readonly property int launcherWidth: Math.round(760 * scale)
    readonly property int launcherHeight: Math.round(600 * scale)
    readonly property int settingsWidth: Math.round(1060 * scale)
    readonly property int settingsHeight: Math.round(720 * scale)
    readonly property int overlayWidth: Math.round(900 * scale)
    readonly property int overlayHeight: Math.round(650 * scale)
    readonly property string fontFamily: "Noto Sans"
    readonly property string monoFamily: "Noto Sans Mono"
    readonly property string iconFamily: "Material Symbols Rounded"
    readonly property int fontCaption: Math.round(11 * scale)
    readonly property int fontBody: Math.round(14 * scale)
    readonly property int fontLabel: Math.round(15 * scale)
    readonly property int fontTitle: Math.round(21 * scale)
    readonly property int fontDisplay: Math.round(34 * scale)
    readonly property int fast: ShellSettings.reduceMotion ? 0 : 140
    readonly property int normal: ShellSettings.reduceMotion ? 0 : 220
}
