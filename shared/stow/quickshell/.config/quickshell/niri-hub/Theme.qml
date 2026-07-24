pragma Singleton
import QtQuick
import "."

QtObject {
    id: root

    readonly property color windowBackground: "#1e1e1e"
    readonly property color elevatedBackground: "#303030"
    readonly property color pillBackground: "#383838"
    readonly property color secondaryBackground: "#252525"
    readonly property color textPrimary: "#ffffff"
    readonly property color textSecondary: "#c0bfbc"
    readonly property color textDisabled: "#aaa7ad"
    readonly property color accent: ShellSettings.accentColor
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color accentForeground: "#1c1b1f"
    readonly property color success: "#57e389"
    readonly property color warning: "#f8e45c"
    readonly property color destructive: "#ff7b63"
    readonly property color border: "#4a4a4a"
    readonly property color hover: "#3d3d3d"
    readonly property color selected: Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property color scrim: "#99000000"
    readonly property color background: windowBackground
    readonly property color surface: windowBackground
    readonly property color surfaceRaised: elevatedBackground
    readonly property color surfaceHover: hover
    readonly property color surfaceHighest: secondaryBackground
    readonly property color foreground: textPrimary
    readonly property color muted: textSecondary
    readonly property color disabled: textDisabled
    readonly property color outline: border
    readonly property color separator: border
    readonly property color danger: destructive

    readonly property real scale: ShellSettings.interfaceScale
    readonly property int unit: Math.round(4 * scale)
    readonly property int radiusSmall: Math.round(6 * scale)
    readonly property int radiusMedium: Math.round(10 * scale)
    readonly property int radiusLarge: Math.round(18 * scale)
    readonly property int radiusPill: 999
    readonly property int controlHeight: Math.round(48 * scale)
    readonly property int rowHeight: Math.round(56 * scale)
    readonly property int cardHeight: Math.round(80 * scale)
    readonly property int iconButtonSize: Math.round(44 * scale)
    readonly property int launcherWidth: Math.round(750 * scale)
    readonly property int launcherHeight: Math.round(600 * scale)
    readonly property int overlayWidth: Math.round(900 * scale)
    readonly property int overlayHeight: Math.round(650 * scale)
    readonly property string fontFamily: "Cantarell"
    readonly property string monoFamily: "Adwaita Mono"
    readonly property real textScale: ShellSettings.textScale
    readonly property int fontCaption: Math.round(12 * textScale)
    readonly property int fontBody: Math.round(16 * textScale)
    readonly property int fontLabel: Math.round(16 * textScale)
    readonly property int fontTitle: Math.round(21 * textScale)
    readonly property int fontDisplay: Math.round(34 * textScale)
    readonly property int fast: ShellSettings.reduceMotion ? 0 : 100
    readonly property int normal: ShellSettings.reduceMotion ? 0 : 180
}
