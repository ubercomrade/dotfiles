pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property bool active: false
    readonly property bool busy: metricsProcess.running
    property bool available: false
    property bool backendMissing: false
    property bool backendProbed: false
    property string errorMessage: "System metrics are paused"

    property real cpuUsage: 0
    property real memoryUsage: 0
    property real memoryUsed: 0
    property real memoryTotal: 0
    property real networkDown: 0
    property real networkUp: 0
    property real diskRead: 0
    property real diskWrite: 0
    property real diskUsage: 0
    property string diskUsed: ""
    property string diskSize: ""
    property string hostname: ""
    property string bootTime: ""
    property var processes: []

    property var cpuHistory: []
    property var memoryHistory: []
    property var networkHistory: []
    property var diskHistory: []

    property string cpuCursor: ""
    property string processCursor: ""
    property string networkCursor: ""
    property string diskCursor: ""
    property int historyLimit: 60
    property date currentTime: new Date()

    readonly property string uptime: {
        if (!bootTime)
            return ""
        const started = new Date(bootTime.replace(" ", "T"))
        const seconds = Math.max(0, Math.floor((currentTime.getTime() - started.getTime()) / 1000))
        if (!isFinite(seconds))
            return ""
        const days = Math.floor(seconds / 86400)
        const hours = Math.floor((seconds % 86400) / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        return days > 0 ? `${days}d ${hours}h` : hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`
    }

    function appendHistory(history, value): var {
        const next = history.slice(Math.max(0, history.length - historyLimit + 1))
        next.push(value)
        return next
    }

    function sum(items, key): real {
        let total = 0
        for (const item of items || [])
            total += Number(item[key]) || 0
        return total
    }

    function poll(): void {
        if (!active || backendMissing || metricsProcess.running)
            return

        const command = ["dgop", "meta", "--json", "--modules",
            "cpu,memory,net-rate,disk-rate,diskmounts,processes,system,hardware",
            "--sort", "cpu", "--limit", "8"]
        if (cpuCursor)
            command.push("--cpu-cursor", cpuCursor)
        if (processCursor)
            command.push("--proc-cursor", processCursor)
        if (networkCursor)
            command.push("--net-rate-cursor", networkCursor)
        if (diskCursor)
            command.push("--disk-rate-cursor", diskCursor)

        metricsProcess.command = command
        metricsProcess.running = true
    }

    function consume(text): void {
        try {
            const data = JSON.parse(text)
            const cpu = data.cpu || {}
            const memory = data.memory || {}
            const netrate = data.netrate || {}
            const diskrate = data.diskrate || {}
            const mounts = data.diskmounts || []
            const rootMount = mounts.find(mount => mount.mount === "/") || mounts[0] || {}

            cpuUsage = Number(cpu.usage) || 0
            memoryUsage = Number(memory.usedPercent) || 0
            memoryUsed = Number(memory.used) || 0
            memoryTotal = Number(memory.total) || 0
            networkDown = sum(netrate.interfaces, "rxrate")
            networkUp = sum(netrate.interfaces, "txrate")
            diskRead = sum(diskrate.disks, "readrate")
            diskWrite = sum(diskrate.disks, "writerate")
            diskUsage = Number(String(rootMount.percent || "0").replace("%", "")) || 0
            diskUsed = rootMount.used || ""
            diskSize = rootMount.size || ""
            processes = data.processes || []
            hostname = data.hardware?.hostname || hostname
            bootTime = data.system?.boottime || bootTime

            cpuCursor = cpu.cursor || cpuCursor
            processCursor = data.cursor || processCursor
            networkCursor = netrate.cursor || networkCursor
            diskCursor = diskrate.cursor || diskCursor

            cpuHistory = appendHistory(cpuHistory, cpuUsage)
            memoryHistory = appendHistory(memoryHistory, memoryUsage)
            networkHistory = appendHistory(networkHistory, networkDown + networkUp)
            diskHistory = appendHistory(diskHistory, diskRead + diskWrite)
            available = true
            errorMessage = ""
        } catch (error) {
            available = false
            errorMessage = `Invalid dgop response: ${error}`
        }
    }

    onActiveChanged: {
        if (active) {
            errorMessage = available ? "" : "Waiting for dgop"
            if (backendProbed)
                poll()
            else
                probeProcess.running = true
        } else {
            metricsProcess.running = false
            errorMessage = "System metrics are paused"
        }
    }

    property Timer pollTimer: Timer {
        interval: 2000
        repeat: true
        running: root.active
        onTriggered: root.poll()
    }

    property Timer uptimeTimer: Timer {
        interval: 60000
        repeat: true
        running: root.active
        onTriggered: root.currentTime = new Date()
    }

    property Process metricsProcess: Process {
        id: metricsProcess

        stdout: StdioCollector {
            onStreamFinished: root.consume(text.trim())
        }
        stderr: StdioCollector {
            id: errorCollector
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.active) {
                root.available = false
                root.errorMessage = exitCode === 127
                    ? "dgop is not installed"
                    : (errorCollector.text.trim() || `dgop exited with code ${exitCode}`)
            }
        }
    }

    property Process probeProcess: Process {
        command: ["sh", "-c", "command -v dgop >/dev/null"]
        onExited: (exitCode, exitStatus) => {
            root.backendProbed = true
            root.backendMissing = exitCode !== 0
            if (root.backendMissing) {
                root.available = false
                root.errorMessage = "dgop is not installed"
            } else if (root.active) {
                root.poll()
            }
        }
    }
}
