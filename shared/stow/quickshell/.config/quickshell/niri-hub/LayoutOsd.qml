import Quickshell
import QtQuick
import QtQuick.Controls
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    property bool showing: false
    readonly property string layoutCode: {
        const layout = shell.keyboardLayout.toLowerCase()
        if (layout.includes("russian"))
            return "RU"
        if (layout.includes("english"))
            return "EN"
        return shell.keyboardLayout.slice(0, 2).toUpperCase()
    }

    screen: screenData
    visible: screenData.name === shell.focusedOutput
    focusable: false
    exclusiveZone: 0
    implicitHeight: 112 * Theme.scale
    color: "transparent"
    mask: Region {}

    anchors {
        top: true
        left: true
        right: true
    }

    Connections {
        target: shell
        function onLayoutOsdSerialChanged(): void {
            window.showing = true
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 1000
        onTriggered: window.showing = false
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        y: window.showing ? Theme.unit * 6 : Theme.unit * 3
        width: 164 * Theme.scale
        height: 64 * Theme.scale
        radius: Theme.radiusMedium
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        opacity: window.showing ? 1 : 0

        Behavior on y { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic } }

        Row {
            anchors.centerIn: parent
            spacing: Theme.unit * 3

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: window.layoutCode
                color: Theme.accent
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: shell.keyboardLayout
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
            }
        }
    }
}
