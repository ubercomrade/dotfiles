import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."

Button {
    id: root

    property var entry: null
    property var shell
    property int thumbnailRevision: 0

    implicitHeight: Math.round(72 * Theme.scale)
    flat: true
    Accessible.name: qsTr("Copy %1").arg(entry?.title || "")
    onClicked: shell.copyHistory(entry)
    onVisibleChanged: loadThumbnail()
    onEntryChanged: Qt.callLater(loadThumbnail)
    Component.onCompleted: Qt.callLater(loadThumbnail)

    function loadThumbnail(): void {
        if (visible && entry?.type === "image" && thumbnail.status !== Image.Ready)
            thumbnailProcess.running = true
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: root.down ? Theme.accentMuted : root.hovered ? Theme.surfaceRaised : "transparent"
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
    }

    contentItem: RowLayout {
        spacing: Theme.unit * 3

        Item {
            Layout.preferredWidth: 56 * Theme.scale
            Layout.preferredHeight: 56 * Theme.scale

            Image {
                id: thumbnail
                anchors.fill: parent
                visible: root.entry?.type === "image" && status === Image.Ready
                source: root.entry?.thumbnailPath ? `file://${root.entry.thumbnailPath}?${root.thumbnailRevision}` : ""
                sourceSize.width: Math.round(56 * Theme.scale)
                sourceSize.height: Math.round(56 * Theme.scale)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            ShellIcon {
                anchors.centerIn: parent
                visible: !thumbnail.visible
                text: root.entry?.iconName || "edit-paste"
                iconSize: 24
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Label {
                Layout.fillWidth: true
                text: root.entry?.title || ""
                textFormat: Text.PlainText
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLabel
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: root.entry?.detail || ""
                textFormat: Text.PlainText
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                elide: Text.ElideRight
            }
        }
    }

    Process {
        id: thumbnailProcess
        command: ["/bin/sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && cliphist decode \"$1\" > \"$2\"", "sh", root.entry?.id || "", root.entry?.thumbnailPath || ""]
        onExited: root.thumbnailRevision++
    }
}
