import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: root
    property string symbol: "settings"
    property string title: ""
    property string description: ""
    default property alias action: actionSlot.data
    implicitHeight: Math.max(68 * Theme.scale, content.implicitHeight + Theme.unit * 4)
    radius: Theme.radiusMedium
    color: Theme.surfaceRaised
    border.width: 1
    border.color: Theme.separator

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.unit * 3
        spacing: Theme.unit * 3
        Rectangle {
            Layout.preferredWidth: 38 * Theme.scale
            Layout.preferredHeight: 38 * Theme.scale
            radius: Theme.radiusMedium
            color: Theme.accentMuted
            ShellIcon { anchors.centerIn: parent; text: root.symbol; color: Theme.accent; iconSize: 21 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { text: root.title; textFormat: Text.PlainText; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
            Label { visible: root.description !== ""; Layout.fillWidth: true; text: root.description; textFormat: Text.PlainText; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; wrapMode: Text.Wrap }
        }
        RowLayout { id: actionSlot; spacing: Theme.unit * 2 }
    }
}
