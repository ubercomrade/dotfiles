pragma Singleton
import QtCore
import QtQuick
import Quickshell.Io
import "."

QtObject {
    id: root

    property string activeTheme: "dark"
    property var palette: darkPalette
    readonly property var darkPalette: ({
        windowBackground: "#1e1e1e",
        elevatedBackground: "#303030",
        pillBackground: "#383838",
        secondaryBackground: "#252525",
        textPrimary: "#ffffff",
        textSecondary: "#c0bfbc",
        textDisabled: "#aaa7ad",
        border: "#4a4a4a",
        hover: "#3d3d3d",
        accentForeground: "#1c1b1f",
        success: "#57e389",
        warning: "#f8e45c",
        destructive: "#ff7b63"
    })
    readonly property string configHome: StandardPaths.writableLocation(StandardPaths.ConfigLocation)
    readonly property string dataHome: StandardPaths.writableLocation(StandardPaths.GenericDataLocation)
    readonly property color windowBackground: palette.windowBackground || darkPalette.windowBackground
    readonly property color elevatedBackground: palette.elevatedBackground || darkPalette.elevatedBackground
    readonly property color pillBackground: palette.pillBackground || darkPalette.pillBackground
    readonly property color secondaryBackground: palette.secondaryBackground || darkPalette.secondaryBackground
    readonly property color textPrimary: palette.textPrimary || darkPalette.textPrimary
    readonly property color textSecondary: palette.textSecondary || darkPalette.textSecondary
    readonly property color textDisabled: palette.textDisabled || darkPalette.textDisabled
    readonly property color accent: ShellSettings.accentColor
    readonly property color accentMuted: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
    readonly property color accentForeground: palette.accentForeground || darkPalette.accentForeground
    readonly property color success: palette.success || darkPalette.success
    readonly property color warning: palette.warning || darkPalette.warning
    readonly property color destructive: palette.destructive || darkPalette.destructive
    readonly property color border: palette.border || darkPalette.border
    readonly property color hover: palette.hover || darkPalette.hover
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

    property FileView themeSelection: FileView {
        id: themeSelection
        path: `${root.configHome}/niri-hub/theme`
        watchChanges: true
        onLoaded: {
            const name = text().trim()
            root.activeTheme = name || "dark"
        }
        onFileChanged: reload()
    }

    property FileView paletteFile: FileView {
        id: paletteFile
        path: `${root.dataHome}/niri-hub/themes/${root.activeTheme}/palette.json`
        watchChanges: true
        onLoaded: {
            try {
                root.palette = JSON.parse(text())
            } catch (_) {
                root.palette = root.darkPalette
            }
        }
        onFileChanged: reload()
        onLoadFailed: _ => root.palette = root.darkPalette
    }
}
