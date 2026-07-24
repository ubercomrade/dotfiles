pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    screen: screenData
    visible: shell.modal !== "none" && screenData?.name === shell.focusedOutput
    focusable: visible
    exclusiveZone: 0
    color: Theme.scrim

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: shell.closeModal()
    }

    Loader {
        id: contentLoader
        anchors.fill: parent
        active: window.visible
        focus: active
        sourceComponent: shell.modal === "launcher" ? launcherComponent : shell.modal === "shortcuts" ? shortcutsComponent : monitorComponent
    }

    Component {
        id: launcherComponent
        Launcher { shell: window.shell }
    }
    Component {
        id: shortcutsComponent
        ShortcutOverlay { shell: window.shell }
    }
    Component {
        id: monitorComponent
        SystemMonitorDashboard { shell: window.shell }
    }

}
