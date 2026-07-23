import QtQuick
import QtQuick.Controls.Basic
import "."

TextField {
    id: root
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.unit * 3
    rightPadding: Theme.unit * 3
    color: Theme.foreground
    placeholderTextColor: Theme.disabled
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentForeground
    font {
        family: Theme.fontFamily
        pixelSize: Theme.fontBody
    }
    background: Rectangle {
        radius: Theme.radiusMedium
        color: Theme.background
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.accent : Theme.outline
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    }
}
