import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    property bool showing: false
    property string kind: "volume"
    property int value: 0
    property bool muted: false

    screen: screenData
    visible: screenData?.name === shell.focusedOutput
    focusable: false
    exclusiveZone: 0
    implicitHeight: 120 * Theme.scale
    color: "transparent"
    mask: Region { }

    anchors {
        top: true
        left: true
        right: true
    }

    Connections {
        target: shell
        function onSystemOsdSerialChanged(): void {
            window.kind = shell.systemOsdKind
            window.value = shell.systemOsdValue
            window.muted = shell.systemOsdMuted
            window.showing = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: window.showing = false
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: window.showing ? Theme.unit * 6 : Theme.unit * 3
        width: 288 * Theme.scale
        height: 72 * Theme.scale
        radius: Theme.radiusPill
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.outline
        opacity: window.showing ? 1 : 0

        Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 3
            spacing: Theme.unit * 3

            Rectangle {
                Layout.preferredWidth: 44 * Theme.scale
                Layout.preferredHeight: 44 * Theme.scale
                radius: Theme.radiusPill
                color: Theme.accentMuted

                ShellIcon {
                    anchors.centerIn: parent
                    text: window.kind === "brightness" ? "display-brightness-symbolic" : window.muted ? "audio-volume-muted-symbolic" : "audio-volume-high-symbolic"
                    color: Theme.accent
                    iconSize: 22
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.unit

                RowLayout {
                    Layout.fillWidth: true
                    Label { text: window.kind === "brightness" ? qsTr("Brightness") : qsTr("Volume"); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Label { text: window.muted ? qsTr("Muted") : qsTr("%1%").arg(window.value); color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 5 * Theme.scale
                    radius: height / 2
                    color: Theme.surfaceRaised

                    Rectangle {
                        width: parent.width * Math.min(100, window.muted ? 0 : window.value) / 100
                        height: parent.height
                        radius: parent.radius
                        color: Theme.accent
                    }
                }
            }
        }
    }
}
