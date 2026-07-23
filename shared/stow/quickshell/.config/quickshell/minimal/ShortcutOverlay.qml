pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root
    required property var shell
    focus: true
    property var shortcuts: [
        { category: "Launcher", keys: ["Super", "D"], action: "Open launcher" },
        { category: "Launcher", keys: ["Super", ","], action: "Open settings" },
        { category: "Launcher", keys: ["Super", "Shift", "M"], action: "Toggle system monitor" },
        { category: "Launcher", keys: ["Super", "Ctrl", "M"], action: "Monitor dashboard" },
        { category: "Launcher", keys: ["Super", "Shift", "/"], action: "Show shortcuts" },
        { category: "Applications", keys: ["Super", "Return"], action: "Terminal" },
        { category: "Applications", keys: ["Super", "E"], action: "Files" },
        { category: "Applications", keys: ["Super", "W"], action: "Browser" },
        { category: "Windows", keys: ["Super", "Q"], action: "Close window" },
        { category: "Windows", keys: ["Super", "Left / Right"], action: "Focus column" },
        { category: "Windows", keys: ["Super", "Up / Down"], action: "Focus workspace" },
        { category: "Windows", keys: ["Super", "Shift", "Left / Right"], action: "Move column" },
        { category: "Windows", keys: ["Super", "Space"], action: "Toggle floating" },
        { category: "Windows", keys: ["Super", "F"], action: "Maximize column" },
        { category: "Windows", keys: ["Super", "Shift", "F"], action: "Fullscreen" },
        { category: "Workspaces", keys: ["Super", "1-9"], action: "Focus workspace" },
        { category: "Workspaces", keys: ["Super", "Shift", "1-9"], action: "Move window" },
        { category: "Screenshots", keys: ["Print"], action: "Screenshot" },
        { category: "Screenshots", keys: ["Ctrl", "Print"], action: "Copy screen" },
        { category: "Screenshots", keys: ["Super", "Shift", "S"], action: "Copy selected area" },
        { category: "Media", keys: ["Brightness + / -"], action: "Adjust brightness" },
        { category: "Media", keys: ["Volume + / -"], action: "Adjust volume" },
        { category: "Media", keys: ["Volume mute"], action: "Toggle audio mute" },
        { category: "Media", keys: ["Mic mute"], action: "Toggle microphone" },
        { category: "Media", keys: ["Play / Pause"], action: "Toggle playback" },
        { category: "Media", keys: ["Next"], action: "Next track" },
        { category: "Media", keys: ["Previous"], action: "Previous track" },
        { category: "Session", keys: ["Ctrl", "Space"], action: "Switch language" },
        { category: "Session", keys: ["Super", "L"], action: "Lock screen" },
        { category: "Session", keys: ["Super", "Shift", "E"], action: "Exit Niri" }
    ]
    property var categories: ["Launcher", "Applications", "Windows", "Workspaces", "Screenshots", "Media", "Session"]

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(Theme.overlayWidth, parent.width - Theme.unit * 8)
        height: Math.min(640 * Theme.scale, parent.height - Theme.unit * 8)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 5
            spacing: Theme.unit * 4

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Keyboard shortcuts"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                Label { text: "Esc to close"; color: Theme.muted }
            }

            Flickable {
                id: shortcutFlickable
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: shortcutColumns.implicitHeight
                focus: true
                activeFocusOnTab: true

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Up)
                        contentY = Math.max(0, contentY - Theme.rowHeight)
                    else if (event.key === Qt.Key_Down)
                        contentY = Math.min(Math.max(0, contentHeight - height), contentY + Theme.rowHeight)
                    else if (event.key === Qt.Key_PageUp)
                        contentY = Math.max(0, contentY - height)
                    else if (event.key === Qt.Key_PageDown)
                        contentY = Math.min(Math.max(0, contentHeight - height), contentY + height)
                    else
                        return
                    event.accepted = true
                }

                Flow {
                    id: shortcutColumns
                    width: parent.width
                    spacing: Theme.unit * 5

                    Repeater {
                        model: root.categories
                        delegate: Column {
                            required property string modelData
                            width: Math.min(410 * Theme.scale, (shortcutColumns.width - Theme.unit * 5) / 2)
                            spacing: Theme.unit * 2

                            Label { text: modelData; color: Theme.accent; font.bold: true }
                            Repeater {
                                model: root.shortcuts.filter(shortcut => shortcut.category === modelData)
                                delegate: RowLayout {
                                    required property var modelData
                                    width: parent.width
                                    spacing: Theme.unit * 2
                                    Row {
                                        spacing: Theme.unit
                                        Repeater {
                                            model: modelData.keys
                                            delegate: Keycap { required property string modelData; label: modelData }
                                        }
                                    }
                                    Label { Layout.fillWidth: true; text: modelData.action; color: Theme.foreground; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: shell.closeModal()
}
