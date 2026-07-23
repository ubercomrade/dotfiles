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
    property bool compact: false
    readonly property bool iconOnly: text === "" && symbol !== ""

    Accessible.name: accessibleName || text || symbol
    implicitHeight: compact ? Math.round(36 * Theme.scale) : Theme.controlHeight
    implicitWidth: iconOnly ? Theme.iconButtonSize : compact ? implicitContentWidth + leftPadding + rightPadding : Math.max(implicitContentWidth + leftPadding + rightPadding, Theme.controlHeight * 2)
    leftPadding: Theme.unit * (compact ? 2 : 3)
    rightPadding: Theme.unit * (compact ? 2 : 3)
    spacing: Theme.unit * 2
    font {
        family: Theme.fontFamily
        pixelSize: compact ? Math.round(13 * Theme.scale) : Theme.fontBody
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
            iconSize: root.compact ? 17 : 19
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
