import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    property bool launcherOpen: false
    property string networkName: "offline"
    property string keyboardLayout: "us"
    property var workspaces: []
    property var workspaceIndices: {
        const indices = new Set(workspaces.map(workspace => workspace.idx))
        for (let index = 1; index <= 9; index++)
            indices.add(index)
        return Array.from(indices).sort((left, right) => left - right)
    }
    property var filteredApplications: DesktopEntries.applications.values.filter(entry =>
        entry.name.toLowerCase().includes(query.text.toLowerCase()))

    function launch(entry): void {
        if (!entry)
            return

        if (entry.runInTerminal) {
            Quickshell.execDetached({
                command: ["kitty", "--"].concat(entry.command),
                workingDirectory: entry.workingDirectory,
            })
        } else {
            entry.execute()
        }
        launcherOpen = false
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            root.launcherOpen = !root.launcherOpen
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: networkProcess
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | sed -n '/^wifi:connected:/s/^[^:]*:[^:]*://p; /^ethernet:connected:/s/^[^:]*:[^:]*://p' | sed -n '1p'"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.networkName = text.trim() || "offline"
        }
    }

    Process {
        id: keyboardProcess
        command: ["niri", "msg", "--json", "keyboard-layouts"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const layouts = JSON.parse(text)
                    root.keyboardLayout = layouts.names[layouts.current_idx] || "us"
                } catch (_) {
                    root.keyboardLayout = "us"
                }
            }
        }
    }

    Process {
        id: workspaceProcess
        command: ["niri", "msg", "--json", "workspaces"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspaces = JSON.parse(text)
                } catch (_) {
                    root.workspaces = []
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            networkProcess.running = true
            keyboardProcess.running = true
            workspaceProcess.running = true
        }
    }

    PanelWindow {
        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 32
        exclusiveZone: implicitHeight
        color: "#1e1e2e"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Row {
                spacing: 3

                Repeater {
                    model: root.workspaceIndices

                    delegate: Button {
                        required property int modelData
                        property bool activeWorkspace: root.workspaces.some(workspace => workspace.idx === modelData && workspace.is_active)
                        text: activeWorkspace ? `[${modelData}]` : modelData
                        implicitWidth: 24
                        implicitHeight: 24
                        font.bold: activeWorkspace
                        onClicked: Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(modelData)])
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Label {
                text: Qt.formatDateTime(clock.date, "ddd, dd MMM  HH:mm")
                color: "#cdd6f4"
            }

            Item { Layout.fillWidth: true }

            Label {
                visible: UPower.displayDevice.isLaptopBattery
                text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                color: "#cdd6f4"
            }

            Label {
                text: root.networkName
                color: "#cdd6f4"
            }

            Label {
                text: root.keyboardLayout.toUpperCase()
                color: "#cdd6f4"
            }
        }
    }

    PanelWindow {
        id: launcher
        visible: root.launcherOpen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "#00000080"
        focusable: true

        onVisibleChanged: {
            if (visible) {
                query.text = ""
                results.currentIndex = 0
                query.forceActiveFocus()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 560
            height: 420
            radius: 8
            color: "#1e1e2e"
            border.width: 2
            border.color: "#89b4fa"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                TextField {
                    id: query
                    Layout.fillWidth: true
                    placeholderText: "Search applications..."
                    onAccepted: {
                        root.launch(root.filteredApplications[results.currentIndex])
                    }
                    onTextChanged: results.currentIndex = 0
                    Keys.onEscapePressed: root.launcherOpen = false
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down && results.count > 0) {
                            results.currentIndex = Math.min(results.currentIndex + 1, results.count - 1)
                            results.positionViewAtIndex(results.currentIndex, ListView.Contain)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up && results.count > 0) {
                            results.currentIndex = Math.max(results.currentIndex - 1, 0)
                            results.positionViewAtIndex(results.currentIndex, ListView.Contain)
                            event.accepted = true
                        }
                    }
                }

                ListView {
                    id: results
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: root.filteredApplications
                    spacing: 4

                    delegate: Button {
                        required property var modelData
                        width: ListView.view.width
                        text: modelData.name
                        highlighted: ListView.isCurrentItem
                        onClicked: {
                            root.launch(modelData)
                        }
                    }
                }
            }
        }
    }
}
