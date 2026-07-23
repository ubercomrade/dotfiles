import QtQuick
import QtQuick.Controls
import "."

Label {
    property int iconSize: 22
    font.family: Theme.iconFamily
    font.pixelSize: Math.round(iconSize * Theme.scale)
    font.weight: Font.Normal
    color: Theme.foreground
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
