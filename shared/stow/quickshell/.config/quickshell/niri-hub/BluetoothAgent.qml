import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property var pendingDevice: null
    property string promptType: "none"
    property string promptValue: ""
    property string promptMessage: ""
    property string statusMessage: ""
    property string statusKind: "idle"
    property bool busy: false

    function pair(device): void {
        if (!device || !device.address || busy)
            return
        pendingDevice = device
        promptType = "none"
        promptValue = ""
        promptMessage = ""
        statusMessage = qsTr("Pairing with %1").arg(device.name || device.deviceName || device.address)
        statusKind = "progress"
        busy = true
        controller.write(`pair ${device.address}\n`)
    }

    function answer(value): void {
        controller.write(`${value}\n`)
        promptType = "none"
        promptValue = ""
        promptMessage = ""
    }

    function cancel(): void {
        if (promptType !== "none")
            controller.write("no\n")
        if (pendingDevice?.address)
            controller.write(`cancel-pairing ${pendingDevice.address}\n`)
        promptType = "none"
        promptValue = ""
        promptMessage = ""
        statusMessage = qsTr("Pairing cancelled")
        statusKind = "cancelled"
        busy = false
        pendingDevice = null
    }

    function consume(output): void {
        const clean = output.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")
        promptMessage = `${promptMessage}${clean}`.slice(-2048)

        let match = promptMessage.match(/Confirm passkey\s+([0-9]+).*\(yes\/no\)/i)
        if (match) {
            promptType = "confirm"
            promptValue = match[1]
            return
        }

        match = promptMessage.match(/Enter PIN code/i)
        if (match) {
            promptType = "pin"
            return
        }

        match = promptMessage.match(/Enter passkey/i)
        if (match) {
            promptType = "passkey"
            return
        }

        match = promptMessage.match(/Authorize service\s+([^\s]+).*\(yes\/no\)/i)
        if (match) {
            promptType = "authorize"
            promptValue = match[1]
            return
        }

        match = promptMessage.match(/(?:Display )?Passkey:\s*([0-9]+)/i)
        if (match) {
            promptType = "display"
            promptValue = match[1]
            return
        }

        if (/Pairing successful/i.test(promptMessage)) {
            if (pendingDevice) {
                pendingDevice.trusted = true
                pendingDevice.connect()
            }
            statusMessage = qsTr("Pairing successful")
            statusKind = "success"
            busy = false
            promptType = "none"
            pendingDevice = null
            promptMessage = ""
        } else {
            match = promptMessage.match(/Failed to pair:\s*([^\r\n]+)/i)
            if (match) {
                statusMessage = qsTr("Pairing failed: %1").arg(match[1])
                statusKind = "error"
                busy = false
                promptType = "none"
                pendingDevice = null
                promptMessage = ""
            }
        }
    }

    property Process controller: Process {
        command: ["env", "LC_ALL=C", "bluetoothctl", "--agent", "KeyboardDisplay"]
        running: true
        stdinEnabled: true

        onStarted: write("default-agent\n")
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            root.promptType = "none"
            root.promptValue = ""
            root.promptMessage = ""
            root.pendingDevice = null
            root.statusMessage = qsTr("Bluetooth agent stopped (%1)").arg(exitCode)
            root.statusKind = "error"
        }

        stdout: SplitParser {
            onRead: data => root.consume(data)
        }
        stderr: SplitParser {
            onRead: data => root.consume(data)
        }
    }
}
