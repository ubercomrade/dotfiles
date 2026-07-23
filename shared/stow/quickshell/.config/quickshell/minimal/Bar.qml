import Quickshell
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

PanelWindow {
    required property var shell
    required property var screenData
    screen: screenData
    implicitHeight: Theme.panelHeight
    exclusiveZone: implicitHeight
    color: Theme.surface

    anchors {
        top: true
        left: true
        right: true
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        border.color: Theme.outline
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.unit * 4
            anchors.rightMargin: Theme.unit * 4
            spacing: Theme.unit * 2

            Button {
                Layout.preferredWidth: 116
                Layout.fillHeight: true
                text: "Applications"
                icon.name: "view-app-grid"
                flat: true
                onClicked: shell.openModal("launcher")
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: Theme.unit

                Repeater {
                    model: shell.workspaceIndices

                    delegate: Button {
                        required property int modelData
                        property bool active: shell.workspaces.some(workspace => workspace.idx === modelData && workspace.is_active)
                        implicitWidth: active ? 34 : 24
                        implicitHeight: 26
                        text: modelData
                        font.bold: active
                        flat: true
                        background: Rectangle {
                            radius: Theme.radiusPill
                            color: parent.active ? Theme.accentMuted : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }
                        onClicked: Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(modelData)])
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: Theme.unit * 2

                Label {
                    visible: UPower.displayDevice.isLaptopBattery
                    text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                    color: Theme.muted
                }
                Label { text: shell.networkName; color: Theme.muted }
                Label { text: shell.keyboardLayout.toUpperCase(); color: Theme.accent; font.bold: true }
                Label { text: Qt.formatDateTime(clock.date, "ddd, dd MMM  HH:mm"); color: Theme.foreground }
            }
        }
    }
}
