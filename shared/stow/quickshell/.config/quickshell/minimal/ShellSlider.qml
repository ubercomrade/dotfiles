import QtQuick
import QtQuick.Controls
import "."

Slider {
    id: control
    implicitHeight: Theme.controlHeight

    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        height: 5 * Theme.scale
        radius: height / 2
        color: Theme.surfaceHighest
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: 18 * Theme.scale
        height: width
        radius: width / 2
        color: Theme.foreground
        border.width: 3
        border.color: Theme.accent
    }
}
