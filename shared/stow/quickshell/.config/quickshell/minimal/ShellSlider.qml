import QtQuick
import QtQuick.Controls.Basic
import "."

Slider {
    id: root

    property string accessibleName: ""

    Accessible.name: accessibleName
    implicitHeight: Theme.controlHeight

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: 5 * Theme.scale
        radius: height / 2
        color: Theme.surfaceHighest
        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.accent
        }
    }
    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: 18 * Theme.scale
        height: width
        radius: width / 2
        color: Theme.foreground
        border.width: root.activeFocus ? 4 : 3
        border.color: root.activeFocus ? Theme.foreground : Theme.accent
    }
}
