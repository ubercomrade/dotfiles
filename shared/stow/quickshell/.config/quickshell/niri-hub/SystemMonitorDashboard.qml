pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import "."

Item {
    id: root
    required property var shell
    focus: true

    implicitWidth: Theme.overlayWidth
    implicitHeight: Theme.overlayHeight
    property var pendingProcess: null

    function formatBytes(value): string {
        const units = ["B", "KiB", "MiB", "GiB", "TiB"]
        let amount = Number(value) || 0
        let unit = 0
        while (amount >= 1024 && unit < units.length - 1) {
            amount /= 1024
            unit++
        }
        return `${amount.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`
    }

    component HistoryGraph: Canvas {
        id: graph
        required property var firstValues
        required property var secondValues
        required property color firstColor
        required property color secondColor
        property real fixedMaximum: 0

        onFirstValuesChanged: requestPaint()
        onSecondValuesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function paintLine(context, values, color, maximum): void {
            if (!values || values.length < 2)
                return
            context.strokeStyle = color
            context.lineWidth = 2
            context.lineJoin = "round"
            context.beginPath()
            for (let index = 0; index < values.length; index++) {
                const x = index * width / Math.max(1, values.length - 1)
                const y = height - Math.min(1, values[index] / maximum) * (height - 4) - 2
                if (index === 0)
                    context.moveTo(x, y)
                else
                    context.lineTo(x, y)
            }
            context.stroke()
        }

        onPaint: {
            const context = getContext("2d")
            context.reset()
            context.strokeStyle = Theme.outline
            context.lineWidth = 1
            for (let row = 1; row < 4; row++) {
                const y = row * height / 4
                context.beginPath()
                context.moveTo(0, y)
                context.lineTo(width, y)
                context.stroke()
            }
            let maximum = fixedMaximum
            if (maximum <= 0) {
                for (const value of (firstValues || []).concat(secondValues || []))
                    maximum = Math.max(maximum, Number(value) || 0)
                maximum = Math.max(1, maximum)
            }
            paintLine(context, firstValues, firstColor, maximum)
            paintLine(context, secondValues, secondColor, maximum)
        }
    }

    component StatCard: Rectangle {
        id: card
        required property string title
        required property string primary
        required property string secondary
        required property color cardColor

        Layout.fillWidth: true
        Layout.preferredHeight: Theme.cardHeight
        radius: Theme.radiusMedium
        color: Theme.surfaceRaised

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 3
            spacing: 1
            Label { text: card.title; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption }
            Label { text: card.primary; color: card.cardColor; font.family: Theme.monoFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.Bold }
            Label { text: card.secondary; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption; elide: Text.ElideRight; Layout.fillWidth: true }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(Theme.overlayWidth, parent.width - Theme.unit * 8)
        height: Math.min(Theme.overlayHeight, parent.height - Theme.unit * 8)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 5
            spacing: Theme.unit * 4

            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label { text: "System monitor"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Label {
                        text: [MetricsService.hostname, MetricsService.uptime ? `up ${MetricsService.uptime}` : ""].filter(Boolean).join(" / ") || "Performance overview"
                        color: Theme.muted
                        font.family: Theme.monoFamily
                    }
                }
                Label {
                    text: MetricsService.available ? "LIVE" : MetricsService.errorMessage
                    color: MetricsService.available ? Theme.success : MetricsService.active ? Theme.warning : Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontCaption
                    font.weight: Font.Bold
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.unit * 3
                StatCard {
                    title: "CPU"
                    primary: `${MetricsService.cpuUsage.toFixed(1)}%`
                    secondary: "total utilization"
                    cardColor: Theme.accent
                }
                StatCard {
                    title: "Memory"
                    primary: `${MetricsService.memoryUsage.toFixed(1)}%`
                    secondary: `${root.formatBytes(MetricsService.memoryUsed * 1024)} of ${root.formatBytes(MetricsService.memoryTotal * 1024)}`
                    cardColor: Theme.success
                }
                StatCard {
                    title: "Network"
                    primary: `Down ${root.formatBytes(MetricsService.networkDown)}/s`
                    secondary: `Up ${root.formatBytes(MetricsService.networkUp)}/s`
                    cardColor: Theme.warning
                }
                StatCard {
                    title: "Disk"
                    primary: `${MetricsService.diskUsage.toFixed(0)}%`
                    secondary: MetricsService.diskUsed && MetricsService.diskSize ? `${MetricsService.diskUsed} of ${MetricsService.diskSize}` : "root filesystem"
                    cardColor: Theme.danger
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(96 * Theme.scale, Math.min(185 * Theme.scale, panel.height - 390 * Theme.scale))
                spacing: Theme.unit * 3

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMedium
                    color: Theme.surfaceRaised
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.unit * 3
                        Label { text: "CPU / memory history"; color: Theme.foreground; font.weight: Font.DemiBold }
                        HistoryGraph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            firstValues: MetricsService.cpuHistory
                            secondValues: MetricsService.memoryHistory
                            firstColor: Theme.accent
                            secondColor: Theme.success
                            fixedMaximum: 100
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMedium
                    color: Theme.surfaceRaised
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.unit * 3
                        Label { text: "I/O throughput"; color: Theme.foreground; font.weight: Font.DemiBold }
                        HistoryGraph {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            firstValues: MetricsService.networkHistory
                            secondValues: MetricsService.diskHistory
                            firstColor: Theme.warning
                            secondColor: Theme.danger
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMedium
                color: Theme.surfaceRaised

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.unit * 3
                    spacing: Theme.unit
                    Label { text: "Top processes"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "PROCESS"; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption; Layout.fillWidth: true }
                        Label { text: "PID"; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption; Layout.preferredWidth: 64 * Theme.scale; horizontalAlignment: Text.AlignRight }
                        Label { text: "CPU"; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption; Layout.preferredWidth: 64 * Theme.scale; horizontalAlignment: Text.AlignRight }
                        Label { text: "MEM"; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption; Layout.preferredWidth: 64 * Theme.scale; horizontalAlignment: Text.AlignRight }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: MetricsService.processes
                        delegate: Button {
                            id: processRow
                            required property var modelData
                            width: ListView.view.width
                            height: 26 * Theme.scale
                            flat: true
                            Accessible.name: qsTr("End process %1").arg(modelData.command || modelData.fullCommand || modelData.pid)
                            onClicked: root.pendingProcess = modelData
                            background: Rectangle {
                                radius: Theme.radiusSmall
                                color: processRow.hovered ? Theme.surfaceHover : "transparent"
                                border.width: processRow.activeFocus ? 2 : 0
                                border.color: Theme.accent
                            }
                            contentItem: RowLayout {
                                Label { text: processRow.modelData.command || processRow.modelData.fullCommand || "unknown"; textFormat: Text.PlainText; color: Theme.foreground; font.family: Theme.monoFamily; elide: Text.ElideRight; Layout.fillWidth: true }
                                Label { text: processRow.modelData.pid; color: Theme.muted; font.family: Theme.monoFamily; Layout.preferredWidth: 64 * Theme.scale; horizontalAlignment: Text.AlignRight }
                                Label { text: `${(Number(processRow.modelData.cpu) || 0).toFixed(1)}%`; color: Theme.accent; font.family: Theme.monoFamily; Layout.preferredWidth: 64 * Theme.scale; horizontalAlignment: Text.AlignRight }
                                Label { text: `${(Number(processRow.modelData.memoryPercent) || 0).toFixed(1)}%`; color: Theme.success; font.family: Theme.monoFamily; Layout.preferredWidth: 64 * Theme.scale; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }
                    Label {
                        visible: MetricsService.processes.length === 0
                        text: MetricsService.available ? "No process data" : MetricsService.errorMessage
                        color: Theme.muted
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.pendingProcess !== null
        focus: visible
        color: Theme.scrim
        z: 10

        onVisibleChanged: {
            if (visible)
                Qt.callLater(cancelProcessButton.forceActiveFocus)
        }

        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: 420 * Theme.scale
            implicitHeight: confirmColumn.implicitHeight + Theme.unit * 10
            radius: Theme.radiusLarge
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline
            ColumnLayout {
                id: confirmColumn
                anchors.fill: parent
                anchors.margins: Theme.unit * 5
                spacing: Theme.unit * 3
                Label { text: "End process?"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                Label { Layout.fillWidth: true; text: root.pendingProcess ? `${root.pendingProcess.command || root.pendingProcess.fullCommand || "Process"} (PID ${root.pendingProcess.pid}) will receive SIGTERM.` : ""; color: Theme.muted; font.family: Theme.fontFamily; wrapMode: Text.Wrap }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    ShellButton { id: cancelProcessButton; text: qsTr("Cancel"); onClicked: root.pendingProcess = null }
                    ShellButton { text: qsTr("End process"); danger: true; onClicked: { Quickshell.execDetached(["kill", "-TERM", String(root.pendingProcess.pid)]); root.pendingProcess = null } }
                }
            }
        }
    }

    Keys.onEscapePressed: {
        if (root.pendingProcess !== null)
            root.pendingProcess = null
        else
            root.shell.closeModal()
    }
}
