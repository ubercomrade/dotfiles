import QtQuick
import QtQuick.Controls
import "."

Rectangle {
    id: root

    required property string label
    implicitWidth: keyLabel.implicitWidth + Theme.unit * 3
    implicitHeight: 24 * Theme.scale
    radius: Theme.radiusSmall
    color: Theme.surfaceRaised
    border.width: 1
    border.color: Theme.outline

    Label {
        id: keyLabel
        anchors.centerIn: parent
        text: root.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
    }
}
