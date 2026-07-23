import QtQuick
import QtQuick.Controls
import "."

Label {
    id: root

    property int iconSize: 22
    Accessible.ignored: true
    font {
        family: Theme.iconFamily
        pixelSize: Math.round(iconSize * Theme.scale)
        weight: Font.Normal
    }
    color: Theme.foreground
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
