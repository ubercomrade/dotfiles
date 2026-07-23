import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import "."

Scope {
    id: root

    property string modal: "none"
    property string focusedOutput: ""
    property string networkName: "offline"
    property string keyboardLayout: "us"
    property var workspaces: []
    property var workspaceIndices: {
        const indices = new Set(workspaces.map(workspace => workspace.idx))
        for (let index = 1; index <= 9; index++)
            indices.add(index)
        return Array.from(indices).sort((left, right) => left - right)
    }

    function openModal(nextModal): void {
        modal = nextModal
        focusedOutputProcess.running = true
    }

    function closeModal(): void {
        modal = "none"
    }

    function applicationResults(query): var {
        const terms = query.toLowerCase().trim().split(/\s+/).filter(term => term.length)
        return DesktopEntries.applications.values.map(entry => {
            const haystack = [entry.name, entry.genericName, entry.comment, entry.id, entry.keywords.join(" ")].join(" ").toLowerCase()
            let score = 0
            let offset = 0
            for (const term of terms) {
                const index = haystack.indexOf(term, offset)
                if (index < 0)
                    return null
                score += index === 0 || haystack[index - 1] === " " ? 100 : 10
                score -= index
                offset = index + term.length
            }
            return { entry, score }
        }).filter(entry => entry !== null).sort((left, right) => right.score - left.score || left.entry.name.localeCompare(right.entry.name))
    }

    function launch(entry): void {
        if (!entry)
            return
        if (entry.runInTerminal) {
            Quickshell.execDetached({ command: ["kitty", "--"].concat(entry.command), workingDirectory: entry.workingDirectory })
        } else {
            entry.execute()
        }
        closeModal()
    }

    function runCommand(command): void {
        Quickshell.execDetached(["sh", "-c", command])
        closeModal()
    }

    function copyHistory(entry): void {
        if (!entry)
            return
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", entry])
        closeModal()
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.modal === "launcher" ? root.closeModal() : root.openModal("launcher") }
    }
    IpcHandler {
        target: "shortcuts"
        function toggle(): void { root.modal === "shortcuts" ? root.closeModal() : root.openModal("shortcuts") }
    }

    Process {
        id: focusedOutputProcess
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.focusedOutput = JSON.parse(text).name || "" } catch (_) { root.focusedOutput = "" }
            }
        }
    }
    Process {
        id: networkProcess
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device | sed -n '/^wifi:connected:/s/^[^:]*:[^:]*://p; /^ethernet:connected:/s/^[^:]*:[^:]*://p' | sed -n '1p'"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.networkName = text.trim() || "offline" }
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
                } catch (_) { root.keyboardLayout = "us" }
            }
        }
    }
    Process {
        id: workspaceProcess
        command: ["niri", "msg", "--json", "workspaces"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.workspaces = JSON.parse(text) } catch (_) { root.workspaces = [] }
            }
        }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            networkProcess.running = true
            keyboardProcess.running = true
            workspaceProcess.running = true
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            Bar {
                required property var modelData
                shell: root
                screenData: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            ModalWindow {
                required property var modelData
                shell: root
                screenData: modelData
            }
        }
    }
}
