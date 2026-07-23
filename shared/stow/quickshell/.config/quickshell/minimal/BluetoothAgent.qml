import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property var pendingDevice: null
    property string promptType: "none"
    property string promptValue: ""
    property string promptMessage: ""
    property string statusMessage: ""
    property bool busy: false
    property int stdoutLength: 0
    property int stderrLength: 0

    function pair(device): void {
        if (!device || !device.address || busy)
            return
        pendingDevice = device
        promptType = "none"
        promptValue = ""
        promptMessage = ""
        statusMessage = `Pairing with ${device.name || device.deviceName || device.address}`
        busy = true
        controller.write(`pair ${device.address}\n`)
    }

    function answer(value): void {
        controller.write(`${value}\n`)
        promptType = "none"
        promptValue = ""
    }

    function cancel(): void {
        if (promptType !== "none")
            controller.write("no\n")
        if (pendingDevice?.address)
            controller.write(`cancel-pairing ${pendingDevice.address}\n`)
        promptType = "none"
        promptValue = ""
        promptMessage = ""
        statusMessage = "Pairing cancelled"
        busy = false
        pendingDevice = null
    }

    function consume(output, source): void {
        let offset = source === "stdout" ? stdoutLength : stderrLength
        if (output.length < offset)
            offset = 0
        if (output.length === offset)
            return

        const clean = output.slice(offset).replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")
        if (source === "stdout")
            stdoutLength = output.length
        else
            stderrLength = output.length
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
            statusMessage = "Pairing successful"
            busy = false
            promptType = "none"
            pendingDevice = null
            promptMessage = ""
        } else {
            match = promptMessage.match(/Failed to pair:\s*([^\r\n]+)/i)
            if (match) {
                statusMessage = `Pairing failed: ${match[1]}`
                busy = false
                promptType = "none"
                pendingDevice = null
                promptMessage = ""
            }
        }
    }

    property Process controller: Process {
        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        running: true
        stdinEnabled: true

        onStarted: write("default-agent\n")
        onExited: (exitCode, exitStatus) => {
            root.busy = false
            root.promptType = "none"
            root.promptValue = ""
            root.promptMessage = ""
            root.pendingDevice = null
            root.statusMessage = `Bluetooth agent stopped (${exitCode})`
        }

        stdout: StdioCollector {
            id: stdoutCollector
            waitForEnd: false
            onDataChanged: root.consume(stdoutCollector.text, "stdout")
        }
        stderr: StdioCollector {
            id: stderrCollector
            waitForEnd: false
            onDataChanged: root.consume(stderrCollector.text, "stderr")
        }
    }
}
