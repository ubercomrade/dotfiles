import QtQuick
import QtQuick.Controls
import "."

Rectangle {
    required property string label
    implicitWidth: keyLabel.implicitWidth + Theme.unit * 3
    implicitHeight: 24
    radius: Theme.radiusSmall
    color: Theme.surfaceRaised
    border.width: 1
    border.color: Theme.outline

    Label {
        id: keyLabel
        anchors.centerIn: parent
        text: parent.label
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontCaption
        font.weight: Font.DemiBold
    }
}
