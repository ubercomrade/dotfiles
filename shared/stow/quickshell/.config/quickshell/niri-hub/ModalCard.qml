import QtQuick
import QtQuick.Layouts
import "."

FocusScope {
    id: root

    property int padding: Theme.unit * 5
    default property alias content: layout.data
    implicitHeight: layout.implicitHeight + padding * 2
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusLarge
        color: Theme.surfaceRaised
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: Theme.unit * 3
    }
}
