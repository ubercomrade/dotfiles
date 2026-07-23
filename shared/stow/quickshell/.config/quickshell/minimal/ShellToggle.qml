import QtQuick
import QtQuick.Controls
import "."

Switch {
    id: control
    implicitWidth: 48 * Theme.scale
    implicitHeight: 28 * Theme.scale
    padding: 0

    indicator: Rectangle {
        implicitWidth: 48 * Theme.scale
        implicitHeight: 28 * Theme.scale
        radius: height / 2
        color: control.checked ? Theme.accent : Theme.surfaceHighest
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.foreground : control.checked ? Theme.accent : Theme.outline

        Rectangle {
            width: 20 * Theme.scale
            height: width
            radius: width / 2
            y: (parent.height - height) / 2
            x: control.checked ? parent.width - width - 4 * Theme.scale : 4 * Theme.scale
            color: control.checked ? Theme.accentForeground : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Item {}
}
