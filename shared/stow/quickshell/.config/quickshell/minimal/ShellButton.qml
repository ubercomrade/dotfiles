import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Button {
    id: control
    property string symbol: ""
    property bool primary: false
    implicitHeight: Theme.controlHeight
    leftPadding: Theme.unit * 3
    rightPadding: Theme.unit * 3
    spacing: Theme.unit * 2
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
    font.weight: Font.DemiBold

    background: Rectangle {
        radius: Theme.radiusMedium
        color: !control.enabled ? Theme.surfaceRaised : control.down ? Theme.surfaceHighest : control.primary ? Theme.accent : control.hovered ? Theme.surfaceHover : Theme.surfaceRaised
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? Theme.accent : control.primary ? "transparent" : Theme.outline
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    contentItem: RowLayout {
        spacing: control.spacing
        ShellIcon {
            visible: control.symbol !== ""
            text: control.symbol
            color: control.primary ? Theme.accentForeground : Theme.foreground
            iconSize: 19
        }
        Label {
            Layout.fillWidth: true
            text: control.text
            color: !control.enabled ? Theme.disabled : control.primary ? Theme.accentForeground : Theme.foreground
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
