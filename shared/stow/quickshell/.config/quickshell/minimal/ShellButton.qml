import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import "."

Button {
    id: root

    property string symbol: ""
    property string accessibleName: ""
    property bool primary: false
    property bool danger: false
    readonly property bool iconOnly: text === "" && symbol !== ""

    Accessible.name: accessibleName || text || symbol
    implicitHeight: Theme.controlHeight
    implicitWidth: iconOnly ? Theme.iconButtonSize : Math.max(implicitContentWidth + leftPadding + rightPadding, Theme.controlHeight * 2)
    leftPadding: Theme.unit * 3
    rightPadding: Theme.unit * 3
    spacing: Theme.unit * 2
    font {
        family: Theme.fontFamily
        pixelSize: Theme.fontBody
        weight: Font.DemiBold
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: !root.enabled ? Theme.surfaceRaised : root.down ? Theme.surfaceHighest : root.danger ? Theme.danger : root.primary ? Theme.accent : root.hovered ? Theme.surfaceHover : Theme.surfaceRaised
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Theme.foreground : root.primary || root.danger ? "transparent" : Theme.outline
        Behavior on color { ColorAnimation { duration: Theme.fast } }
    }
    contentItem: RowLayout {
        spacing: root.iconOnly ? 0 : root.spacing
        ShellIcon {
            Layout.fillWidth: root.iconOnly
            visible: root.symbol !== ""
            text: root.symbol
            color: root.primary || root.danger ? Theme.accentForeground : Theme.foreground
            iconSize: 19
        }
        Label {
            visible: !root.iconOnly
            Layout.fillWidth: true
            text: root.text
            color: !root.enabled ? Theme.disabled : root.primary || root.danger ? Theme.accentForeground : Theme.foreground
            font: root.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
