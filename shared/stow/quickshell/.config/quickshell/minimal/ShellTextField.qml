import QtQuick
import QtQuick.Controls
import "."

TextField {
    id: control
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.unit * 3
    rightPadding: Theme.unit * 3
    color: Theme.foreground
    placeholderTextColor: Theme.disabled
    selectionColor: Theme.accent
    selectedTextColor: Theme.accentForeground
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
    background: Rectangle {
        radius: Theme.radiusMedium
        color: Theme.background
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : Theme.outline
        Behavior on border.color { ColorAnimation { duration: Theme.fast } }
    }
}
