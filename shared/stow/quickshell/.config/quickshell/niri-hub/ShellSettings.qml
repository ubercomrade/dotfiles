pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property int version: 5
    property string accentName: "blue"
    property real interfaceScale: 1.0
    property real textScale: 1.0
    property bool reduceMotion: false
    property bool monitorVisible: false
    property bool monitorClickThrough: false
    property int monitorRightMargin: 24
    property int monitorBottomMargin: 24
    property bool loading: true

    readonly property color accentColor: {
        switch (accentName) {
        case "violet": return "#b4a0ff"
        case "cyan": return "#63d8e8"
        case "green": return "#83d6a2"
        case "rose": return "#f49ab8"
        default: return "#89b4fa"
        }
    }

    function apply(data): void {
        accentName = data.accentName ?? accentName
        const savedInterfaceScale = Number(data.interfaceScale)
        interfaceScale = Number.isFinite(savedInterfaceScale) ? Math.max(0.75, Math.min(2, savedInterfaceScale)) : interfaceScale
        const savedTextScale = Number(data.textScale)
        textScale = Number.isFinite(savedTextScale) ? Math.max(0.8, Math.min(1.5, savedTextScale)) : textScale
        reduceMotion = data.reduceMotion ?? reduceMotion
        monitorVisible = (data.version ?? 0) < 2 ? true : (data.monitorVisible ?? monitorVisible)
        monitorClickThrough = data.monitorClickThrough ?? monitorClickThrough
        monitorRightMargin = data.monitorRightMargin ?? monitorRightMargin
        monitorBottomMargin = data.monitorBottomMargin ?? monitorBottomMargin
    }

    function load(): void {
        let migrated = false
        try {
            const data = JSON.parse(store.text || "{}")
            migrated = (data.version ?? 0) < version
            apply(data)
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
            textScale,
            reduceMotion,
            monitorVisible,
            monitorClickThrough,
            monitorRightMargin,
            monitorBottomMargin
        }, null, 2))
    }

    onAccentNameChanged: scheduleSave()
    onInterfaceScaleChanged: scheduleSave()
    onTextScaleChanged: scheduleSave()
    onReduceMotionChanged: scheduleSave()
    onMonitorVisibleChanged: scheduleSave()
    onMonitorClickThroughChanged: scheduleSave()
    onMonitorRightMarginChanged: scheduleSave()
    onMonitorBottomMarginChanged: scheduleSave()

    property Timer saveTimer: Timer {
        interval: 180
        onTriggered: root.save()
    }

    property FileView store: FileView {
        path: Quickshell.statePath("niri-hub/settings.json")
        watchChanges: true
        atomicWrites: true
        onLoaded: root.load()
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                legacyStore.reload()
            else
                root.loading = false
        }
    }
    property FileView legacyStore: FileView {
        path: Quickshell.statePath("minimal-shell/settings.json")
        onLoaded: {
            try { root.apply(JSON.parse(text || "{}")) } catch (_) {}
            root.loading = false
            root.save()
        }
        onLoadFailed: _ => { root.loading = false; root.save() }
    }
}
