import Quickshell
import Quickshell.Io
import QtQuick
import "."

Scope {
    id: root

    property string modal: "none"
    property string pendingModal: "none"
    property string focusedOutput: ""
    property var keyboardLayouts: ["English (US)", "Russian"]
    property int keyboardLayoutIndex: 0
    property int layoutOsdSerial: 0
    property string keyboardLayout: keyboardLayouts[keyboardLayoutIndex] || "Unknown"
    property alias bluetoothAgent: btAgent

    function openModal(nextModal): void {
        pendingModal = nextModal
        focusedOutputProcess.running = true
    }

    function closeModal(): void {
        if (btAgent.promptType !== "none")
            btAgent.cancel()
        modal = "none"
        pendingModal = "none"
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

    BluetoothAgent {
        id: btAgent
    }
    Connections {
        target: btAgent
        function onPromptTypeChanged(): void {
            if (btAgent.promptType !== "none" && root.modal !== "launcher")
                root.openModal("launcher")
        }
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
                root.modal = root.pendingModal
            }
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
                    root.keyboardLayouts = layouts.names || root.keyboardLayouts
                    root.keyboardLayoutIndex = layouts.current_idx ?? 0
                } catch (_) {}
            }
        }
    }
    Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                let event
                try { event = JSON.parse(data) } catch (_) { return }

                if (event.WorkspacesChanged) {
                    const focused = event.WorkspacesChanged.workspaces.find(workspace => workspace.is_focused)
                    if (focused?.output)
                        root.focusedOutput = focused.output
                } else if (event.KeyboardLayoutsChanged) {
                    const layouts = event.KeyboardLayoutsChanged.keyboard_layouts
                    root.keyboardLayouts = layouts.names || root.keyboardLayouts
                    root.keyboardLayoutIndex = layouts.current_idx ?? root.keyboardLayoutIndex
                } else if (event.KeyboardLayoutSwitched) {
                    const layout = event.KeyboardLayoutSwitched
                    root.keyboardLayoutIndex = layout.idx ?? layout.current_idx ?? root.keyboardLayoutIndex
                    root.layoutOsdSerial++
                }
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
    Variants {
        model: Quickshell.screens
        delegate: Component {
            LayoutOsd {
                required property var modelData
                shell: root
                screenData: modelData
            }
        }
    }
}
