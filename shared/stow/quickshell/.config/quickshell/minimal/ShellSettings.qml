pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property int version: 2
    property string accentName: "blue"
    property real interfaceScale: 1.0
    property bool reduceMotion: false
    property bool monitorVisible: false
    property bool monitorClickThrough: false
    property int monitorRightMargin: 24
    property int monitorBottomMargin: 24
    property string settingsSection: "network"
    property var outputScales: ({})
    property bool loading: true

    readonly property color accentColor: {
        switch (accentName) {
        case "violet": return "#b4a0ff"
        case "cyan": return "#63d8e8"
        case "green": return "#83d6a2"
        case "rose": return "#f49ab8"
        default: return "#8ab4f8"
        }
    }

    function load(): void {
        let migrated = false
        try {
            const data = JSON.parse(store.text || "{}")
            migrated = (data.version ?? 0) < version
            accentName = data.accentName ?? accentName
            interfaceScale = data.interfaceScale ?? interfaceScale
            reduceMotion = data.reduceMotion ?? reduceMotion
            monitorVisible = (data.version ?? 0) < 2 ? true : (data.monitorVisible ?? monitorVisible)
            monitorClickThrough = data.monitorClickThrough ?? monitorClickThrough
            monitorRightMargin = data.monitorRightMargin ?? monitorRightMargin
            monitorBottomMargin = data.monitorBottomMargin ?? monitorBottomMargin
            settingsSection = data.settingsSection ?? settingsSection
            outputScales = data.outputScales ?? outputScales
        } catch (_) {}
        loading = false
        if (migrated)
            save()
    }

    function scheduleSave(): void {
        if (!loading)
            saveTimer.restart()
    }

    function save(): void {
        store.setText(JSON.stringify({
            version,
            accentName,
            interfaceScale,
            reduceMotion,
            monitorVisible,
            monitorClickThrough,
            monitorRightMargin,
            monitorBottomMargin,
            settingsSection,
            outputScales
        }, null, 2))
    }

    onAccentNameChanged: scheduleSave()
    onInterfaceScaleChanged: scheduleSave()
    onReduceMotionChanged: scheduleSave()
    onMonitorVisibleChanged: scheduleSave()
    onMonitorClickThroughChanged: scheduleSave()
    onMonitorRightMarginChanged: scheduleSave()
    onMonitorBottomMarginChanged: scheduleSave()
    onSettingsSectionChanged: scheduleSave()
    onOutputScalesChanged: scheduleSave()

    property Timer saveTimer: Timer {
        interval: 180
        onTriggered: root.save()
    }

    property FileView store: FileView {
        path: Quickshell.statePath("minimal-shell/settings.json")
        watchChanges: true
        atomicWrites: true
        onLoaded: root.load()
        onFileChanged: reload()
        onLoadFailed: error => {
            root.loading = false
            if (error === FileViewError.FileNotFound)
                root.save()
        }
    }
}
