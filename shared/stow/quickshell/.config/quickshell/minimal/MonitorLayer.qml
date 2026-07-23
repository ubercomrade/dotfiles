import QtQuick
import QtQuick.Controls
import Quickshell
import "."

PanelWindow {
    id: window
    required property var shell
    required property var screenData
    property real pressGlobalX: 0
    property real pressGlobalY: 0
    property int startRight: 0
    property int startBottom: 0
    readonly property int maximumRightMargin: Math.max(0, screenData.width - implicitWidth)
    readonly property int maximumBottomMargin: Math.max(0, screenData.height - implicitHeight)

    function clampMargins(): void {
        ShellSettings.monitorRightMargin = Math.max(0, Math.min(maximumRightMargin, ShellSettings.monitorRightMargin))
        ShellSettings.monitorBottomMargin = Math.max(0, Math.min(maximumBottomMargin, ShellSettings.monitorBottomMargin))
    }

    screen: screenData
    visible: ShellSettings.monitorVisible && screenData.name === shell.focusedOutput
    focusable: false
    exclusiveZone: 0
    implicitWidth: 344 * Theme.scale
    implicitHeight: 424 * Theme.scale
    color: "transparent"
    mask: Region { item: ShellSettings.monitorClickThrough ? null : card }
    anchors { right: true; bottom: true }
    margins { right: ShellSettings.monitorRightMargin; bottom: ShellSettings.monitorBottomMargin }

    onMaximumRightMarginChanged: clampMargins()
    onMaximumBottomMarginChanged: clampMargins()

    Item {
        id: card
        anchors.fill: parent
        anchors.margins: Theme.unit * 3
        Loader {
            anchors.fill: parent
            active: window.visible
            sourceComponent: SystemMonitorWidget { }
        }

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
                ShellSettings.monitorRightMargin = Math.max(0, Math.min(window.maximumRightMargin, window.startRight - Math.round(point.x - window.pressGlobalX)))
                ShellSettings.monitorBottomMargin = Math.max(0, Math.min(window.maximumBottomMargin, window.startBottom - Math.round(point.y - window.pressGlobalY)))
            }
            onDoubleClicked: shell.openModal("monitor")
        }
    }
}
