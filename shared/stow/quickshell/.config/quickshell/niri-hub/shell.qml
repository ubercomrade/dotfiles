pragma ComponentBehavior: Bound
//@ pragma IconTheme Adwaita

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import "."
import "services"

Scope {
    id: root

    property string modal: "none"
    property string pendingModal: "none"
    property string focusedOutput: ""
    property var keyboardLayouts: ["English (US)", "Russian"]
    property int keyboardLayoutIndex: 0
    property int layoutOsdSerial: 0
    readonly property string keyboardLayout: keyboardLayouts[keyboardLayoutIndex] || "Unknown"
    property alias bluetoothAgent: btAgent
    property alias polkitFlow: polkitAgent.flow
    property alias applicationService: applicationService
    property alias clipboardService: clipboardService
    property alias powerService: powerService

    function applicationResults(query): var { return applicationService.results(query) }
    function launch(entry): void { applicationService.launch(entry); closeModal() }
    function runCommand(command): void { applicationService.runCommand(command); closeModal() }
    function copyHistory(entry): void {
        clipboardService.copy(entry.id)
        closeModal()
    }

    function openModal(nextModal): void {
        pendingModal = nextModal
        focusedOutputProcess.running = true
    }

    function finishModalOpen(outputName): void {
        focusedOutput = outputName || Quickshell.screens[0]?.name || ""
        if (focusedOutput !== "")
            modal = pendingModal
    }

    function closeModal(): void {
        if (btAgent.promptType !== "none")
            btAgent.cancel()
        if (modal === "launcher")
            LauncherState.reset()
        modal = "none"
        pendingModal = "none"
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.modal === "launcher" ? root.closeModal() : root.openModal("launcher") }
        function apps(): void { LauncherState.page = "apps"; root.openModal("launcher") }
        function clipboard(): void { LauncherState.page = "clipboard"; root.openModal("launcher") }
        function wifi(): void { LauncherState.page = "wifi"; root.openModal("launcher") }
        function bluetooth(): void { LauncherState.page = "bluetooth"; root.openModal("launcher") }
    }
    IpcHandler {
        target: "monitor"
        function toggle(): void { ShellSettings.monitorVisible = !ShellSettings.monitorVisible }
        function dashboard(): void { root.modal === "monitor" ? root.closeModal() : root.openModal("monitor") }
        function clickThrough(): void { ShellSettings.monitorClickThrough = !ShellSettings.monitorClickThrough }
    }

    BluetoothAgent {
        id: btAgent
    }
    ApplicationService { id: applicationService }
    ClipboardService { id: clipboardService }
    PowerService { id: powerService }
    PolkitAgent {
        id: polkitAgent
        path: "/org/quickshell/NiriHub/PolkitAgent"
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
                try { root.finishModalOpen(JSON.parse(text).name) } catch (_) { root.finishModalOpen("") }
            }
        }
        onExited: {
            if (root.pendingModal !== "none" && root.modal !== root.pendingModal)
                root.finishModalOpen("")
        }
    }
    Binding {
        target: MetricsService
        property: "active"
        value: ShellSettings.monitorVisible || root.modal === "monitor"
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
        id: niriEventProcess
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        onExited: niriEventRestart.restart()
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
    Timer {
        id: niriEventRestart
        interval: 1000
        onTriggered: {
            keyboardProcess.running = true
            focusedOutputProcess.running = true
            niriEventProcess.running = true
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
    Variants {
        model: Quickshell.screens
        delegate: Component {
            MonitorLayer {
                required property var modelData
                shell: root
                screenData: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PolkitWindow {
                required property var modelData
                shell: root
                screenData: modelData
                flow: root.polkitFlow
            }
        }
    }
}
