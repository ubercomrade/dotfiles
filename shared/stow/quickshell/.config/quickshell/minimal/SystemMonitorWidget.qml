import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    implicitWidth: 320
    implicitHeight: 400
    radius: Theme.radiusLarge
    color: Theme.surface
    border.width: 1
    border.color: Theme.outline

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

    component MiniGraph: Canvas {
        id: graph
        required property var values
        required property color lineColor
        property real fixedMaximum: 0

        onValuesChanged: requestPaint()
        onLineColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d")
            context.reset()
            if (!values || values.length < 2)
                return
            let maximum = fixedMaximum
            if (maximum <= 0) {
                for (const value of values)
                    maximum = Math.max(maximum, Number(value) || 0)
                maximum = Math.max(1, maximum)
            }
            context.strokeStyle = lineColor
            context.lineWidth = 2
            context.lineJoin = "round"
            context.beginPath()
            for (let index = 0; index < values.length; index++) {
                const x = index * width / Math.max(1, values.length - 1)
                const y = height - Math.min(1, values[index] / maximum) * (height - 2) - 1
                if (index === 0)
                    context.moveTo(x, y)
                else
                    context.lineTo(x, y)
            }
            context.stroke()
        }
    }

    component MetricRow: Rectangle {
        id: metric
        required property string title
        required property string value
        required property color metricColor
        required property var history
        property real graphMaximum: 0

        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: Theme.radiusMedium
        color: Theme.surfaceRaised

        RowLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 3
            spacing: Theme.unit * 3

            Rectangle {
                Layout.preferredWidth: 4
                Layout.fillHeight: true
                radius: Theme.radiusSmall
                color: metric.metricColor
            }
            ColumnLayout {
                Layout.preferredWidth: 82
                spacing: 1
                Label { text: metric.title; color: Theme.muted; font.family: Theme.monoFamily; font.pixelSize: Theme.fontCaption }
                Label { text: metric.value; color: Theme.foreground; font.family: Theme.monoFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
            }
            MiniGraph {
                Layout.fillWidth: true
                Layout.fillHeight: true
                values: metric.history
                lineColor: metric.metricColor
                fixedMaximum: metric.graphMaximum
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.unit * 4
        spacing: Theme.unit * 3

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    text: MetricsService.hostname || "System monitor"
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                }
                Label {
                    text: MetricsService.uptime ? `Up ${MetricsService.uptime}` : "Live performance"
                    color: Theme.muted
                    font.family: Theme.monoFamily
                    font.pixelSize: Theme.fontCaption
                }
            }
            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: MetricsService.available ? Theme.success : MetricsService.active ? Theme.warning : Theme.muted
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: !MetricsService.available
            Label {
                anchors.fill: parent
                text: MetricsService.errorMessage
                color: MetricsService.active ? Theme.warning : Theme.muted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.Wrap
            }
        }

        MetricRow {
            title: "CPU"
            value: `${MetricsService.cpuUsage.toFixed(0)}%`
            metricColor: Theme.accent
            history: MetricsService.cpuHistory
            graphMaximum: 100
        }
        MetricRow {
            title: "Memory"
            value: `${MetricsService.memoryUsage.toFixed(0)}%`
            metricColor: Theme.success
            history: MetricsService.memoryHistory
            graphMaximum: 100
        }
        MetricRow {
            title: "Network"
            value: `Down ${root.formatBytes(MetricsService.networkDown)}/s`
            metricColor: Theme.warning
            history: MetricsService.networkHistory
        }
        MetricRow {
            title: "Disk"
            value: MetricsService.diskUsage > 0 ? `${MetricsService.diskUsage.toFixed(0)}% full` : "No data"
            metricColor: Theme.danger
            history: MetricsService.diskHistory
        }
        Item { Layout.fillHeight: true }
    }
}
