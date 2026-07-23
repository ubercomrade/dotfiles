import QtQuick
import QtQuick.Controls.Basic
import "."

Switch {
    id: root

    property string accessibleName: ""

    Accessible.name: accessibleName || text
    implicitWidth: text ? contentItem.implicitWidth : indicator.implicitWidth
    implicitHeight: 28 * Theme.scale
    padding: 0

    indicator: Rectangle {
        id: indicator
        x: root.mirrored ? root.width - width : 0
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 48 * Theme.scale
        implicitHeight: 28 * Theme.scale
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHighest
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.foreground : root.checked ? Theme.accent : Theme.outline

        Rectangle {
            width: 20 * Theme.scale
            height: width
            radius: width / 2
            y: (parent.height - height) / 2
            x: root.checked ? parent.width - width - 4 * Theme.scale : 4 * Theme.scale
            color: root.checked ? Theme.accentForeground : Theme.muted
            Behavior on x { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        }
    }
    contentItem: Label {
        visible: root.text !== ""
        leftPadding: root.mirrored ? 0 : indicator.width + Theme.unit * 2
        rightPadding: root.mirrored ? indicator.width + Theme.unit * 2 : 0
        text: root.text
        color: root.enabled ? Theme.foreground : Theme.disabled
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        verticalAlignment: Text.AlignVCenter
    }
}
