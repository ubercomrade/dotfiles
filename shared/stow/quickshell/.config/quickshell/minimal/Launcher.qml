import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root
    required property var shell
    property string mode: "apps"
    property int currentIndex: 0
    property var clipboardEntries: []
    property var appEntries: shell.applicationResults(query.text)
    property var visibleEntries: mode === "apps" ? appEntries : mode === "clipboard" ? clipboardEntries.filter(entry => entry.toLowerCase().includes(query.text.toLowerCase())) : []

    function selectOffset(offset): void {
        if (visibleEntries.length === 0)
            return
        currentIndex = (currentIndex + offset + visibleEntries.length) % visibleEntries.length
        results.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    function activate(): void {
        if (mode === "apps")
            shell.launch(appEntries[currentIndex]?.entry)
        else if (mode === "run" && query.text.trim())
            shell.runCommand(query.text)
        else if (mode === "clipboard")
            shell.copyHistory(visibleEntries[currentIndex])
    }

    function setMode(nextMode): void {
        mode = nextMode
        currentIndex = 0
        query.forceActiveFocus()
        if (nextMode === "clipboard")
            clipboardProcess.running = true
    }

    Process {
        id: clipboardProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardEntries = text.trim() ? text.trim().split("\n") : []
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(640, parent.width - Theme.unit * 8)
        height: Math.min(520, parent.height - Theme.unit * 8)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 5
            spacing: Theme.unit * 3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.unit * 2

                Repeater {
                    model: [{ id: "apps", label: "Apps" }, { id: "run", label: "Run" }, { id: "clipboard", label: "Clipboard" }]
                    delegate: Button {
                        required property var modelData
                        text: modelData.label
                        checkable: true
                        checked: root.mode === modelData.id
                        flat: true
                        onClicked: root.setMode(modelData.id)
                    }
                }
                Item { Layout.fillWidth: true }
                Label { text: "Tab switches modes"; color: Theme.muted; font.pixelSize: 12 }
            }

            TextField {
                id: query
                Layout.fillWidth: true
                placeholderText: root.mode === "apps" ? "Search applications" : root.mode === "run" ? "Run command" : "Search clipboard history"
                selectByMouse: true
                onTextChanged: root.currentIndex = 0
                onAccepted: root.activate()
                Component.onCompleted: forceActiveFocus()
                Keys.onEscapePressed: shell.closeModal()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Tab) {
                        root.setMode(root.mode === "apps" ? "run" : root.mode === "run" ? "clipboard" : "apps")
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backtab) {
                        root.setMode(root.mode === "apps" ? "clipboard" : root.mode === "run" ? "apps" : "run")
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier)) {
                        root.selectOffset(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier)) {
                        root.selectOffset(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Home) {
                        root.currentIndex = 0
                        event.accepted = true
                    } else if (event.key === Qt.Key_End) {
                        root.currentIndex = Math.max(0, root.visibleEntries.length - 1)
                        event.accepted = true
                    }
                }
            }

            Label {
                visible: root.mode === "run"
                Layout.fillWidth: true
                text: "Commands run through your shell. Review the command before pressing Enter."
                color: Theme.muted
                wrapMode: Text.Wrap
            }

            ListView {
                id: results
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.unit
                model: root.mode === "run" ? [] : root.visibleEntries

                delegate: Button {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 52
                    highlighted: root.currentIndex === index
                    flat: true
                    onClicked: {
                        root.currentIndex = index
                        root.activate()
                    }

                    contentItem: RowLayout {
                        spacing: Theme.unit * 3
                        Image {
                            visible: root.mode === "apps"
                            source: Quickshell.iconPath(root.mode === "apps" ? modelData.entry.icon : "edit-paste", "application-x-executable")
                            sourceSize.width: 24
                            sourceSize.height: 24
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Label {
                                Layout.fillWidth: true
                                text: root.mode === "apps" ? modelData.entry.name : modelData
                                color: Theme.foreground
                                elide: Text.ElideRight
                            }
                            Label {
                                visible: root.mode === "apps" && (modelData.entry.genericName || modelData.entry.comment)
                                Layout.fillWidth: true
                                text: modelData.entry.genericName || modelData.entry.comment
                                color: Theme.muted
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: root.mode !== "run" && root.visibleEntries.length === 0
                    text: root.mode === "clipboard" ? "Clipboard history is empty" : "No applications found"
                    color: Theme.muted
                }
            }
        }
    }
}
