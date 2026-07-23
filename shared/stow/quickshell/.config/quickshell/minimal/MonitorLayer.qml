import Quickshell
import QtQuick
import QtQuick.Controls
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    property real pressGlobalX: 0
    property real pressGlobalY: 0
    property int startRight: 0
    property int startBottom: 0

    screen: screenData
    visible: ShellSettings.monitorVisible && (shell.focusedOutput === "" || screenData.name === shell.focusedOutput)
    focusable: false
    exclusiveZone: 0
    implicitWidth: 344 * Theme.scale
    implicitHeight: 424 * Theme.scale
    color: "transparent"
    mask: Region { item: ShellSettings.monitorClickThrough ? null : card }
    anchors { right: true; bottom: true }
    margins { right: ShellSettings.monitorRightMargin; bottom: ShellSettings.monitorBottomMargin }

    Rectangle {
        id: card
        anchors.fill: parent
        anchors.margins: Theme.unit * 3
        color: "transparent"
        SystemMonitorWidget { anchors.fill: parent }

        MouseArea {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 58 * Theme.scale
            cursorShape: Qt.SizeAllCursor
            onPressed: event => {
                const point = mapToGlobal(event.x, event.y)
                window.pressGlobalX = point.x
                window.pressGlobalY = point.y
                window.startRight = ShellSettings.monitorRightMargin
                window.startBottom = ShellSettings.monitorBottomMargin
            }
            onPositionChanged: event => {
                if (!pressed) return
                const point = mapToGlobal(event.x, event.y)
                ShellSettings.monitorRightMargin = Math.max(0, window.startRight - Math.round(point.x - window.pressGlobalX))
                ShellSettings.monitorBottomMargin = Math.max(0, window.startBottom - Math.round(point.y - window.pressGlobalY))
            }
            onDoubleClicked: shell.openModal("monitor")
        }
    }
}
