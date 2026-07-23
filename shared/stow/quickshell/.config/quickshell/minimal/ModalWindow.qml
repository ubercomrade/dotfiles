import Quickshell
import QtQuick
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    screen: screenData
    visible: shell.modal !== "none" && (shell.focusedOutput === "" || screenData.name === shell.focusedOutput)
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
        anchors.fill: parent
        active: window.visible
        sourceComponent: shell.modal === "launcher" ? launcherComponent : shortcutsComponent
    }

    Component {
        id: launcherComponent
        Launcher { shell: window.shell }
    }
    Component {
        id: shortcutsComponent
        ShortcutOverlay { shell: window.shell }
    }

}
