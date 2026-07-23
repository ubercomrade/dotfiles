import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root
    required property var shell
    property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) || null
    property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((a, b) => Number(b.connected) - Number(a.connected) || b.signalStrength - a.signalStrength) : []
    property var bluetoothAdapter: Bluetooth.defaultAdapter
    property var outputs: []
    property var passwordNetwork: null
    property var pendingOutputChange: null
    property string statusMessage: ""
    property var pages: [
        { id: "network", label: "Network", icon: "wifi" }, { id: "bluetooth", label: "Bluetooth", icon: "bluetooth" },
        { id: "audio", label: "Audio", icon: "volume_up" }, { id: "displays", label: "Displays", icon: "monitor" },
        { id: "power", label: "Power", icon: "battery_charging_full" }, { id: "input", label: "Input", icon: "keyboard" },
        { id: "appearance", label: "Appearance", icon: "palette" }, { id: "system", label: "System", icon: "memory" }
    ]
    readonly property int pageIndex: Math.max(0, pages.findIndex(page => page.id === ShellSettings.settingsSection))

    function selectPage(id): void {
        ShellSettings.settingsSection = id
        statusMessage = ""
        if (id === "displays") outputsProcess.running = true
    }

    function activateNetwork(network): void {
        statusMessage = ""
        if (network.connected) network.disconnect()
        else if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) network.connect()
        else if (network.security === WifiSecurityType.Sae || network.security === WifiSecurityType.Wpa2Psk || network.security === WifiSecurityType.WpaPsk) {
            passwordNetwork = network
            wifiPassword.text = ""
            wifiPassword.forceActiveFocus()
        } else statusMessage = "This network security type is not supported"
    }

    function applyOutputScale(name, scale): void {
        if (pendingOutputChange && pendingOutputChange.name !== name)
            revertOutputChange()
        const bounded = Math.max(0.75, Math.min(3, Math.round(scale * 4) / 4))
        const output = outputs.find(candidate => candidate.name === name)
        const previous = pendingOutputChange?.name === name ? pendingOutputChange.previous : (output?.logical?.scale || 1)
        Quickshell.execDetached(["niri", "msg", "output", name, "scale", String(bounded)])
        pendingOutputChange = { name, previous, next: bounded }
        outputRollback.restart()
        outputRefresh.restart()
    }

    function keepOutputChange(): void {
        if (!pendingOutputChange) return
        const next = Object.assign({}, ShellSettings.outputScales)
        next[pendingOutputChange.name] = pendingOutputChange.next
        ShellSettings.outputScales = next
        pendingOutputChange = null
        outputRollback.stop()
    }

    function revertOutputChange(): void {
        if (!pendingOutputChange) return
        Quickshell.execDetached(["niri", "msg", "output", pendingOutputChange.name, "scale", String(pendingOutputChange.previous)])
        pendingOutputChange = null
        outputRollback.stop()
        outputRefresh.restart()
    }

    Component.onCompleted: { MetricsService.active = true; outputsProcess.running = true }
    Component.onDestruction: {
        if (pendingOutputChange)
            revertOutputChange()
        MetricsService.active = ShellSettings.monitorVisible
    }

    Binding { target: root.wifiDevice; property: "scannerEnabled"; value: ShellSettings.settingsSection === "network" && Networking.wifiEnabled; when: root.wifiDevice !== null; restoreMode: Binding.RestoreBindingOrValue }
    Binding { target: root.bluetoothAdapter; property: "discovering"; value: ShellSettings.settingsSection === "bluetooth" && root.bluetoothAdapter?.enabled; when: root.bluetoothAdapter !== null; restoreMode: Binding.RestoreBindingOrValue }
    PwObjectTracker { objects: Pipewire.nodes.values }

    Process {
        id: outputsProcess
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    root.outputs = Object.keys(parsed).map(name => Object.assign({ name }, parsed[name]))
                } catch (_) { root.outputs = [] }
            }
        }
    }
    Timer { id: outputRefresh; interval: 400; onTriggered: outputsProcess.running = true }
    Timer { id: outputRollback; interval: 15000; onTriggered: root.revertOutputChange() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(1060, parent.width - Theme.unit * 8)
        height: Math.min(720, parent.height - Theme.unit * 8)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        clip: true

        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 230 * Theme.scale
                color: Theme.background
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.unit * 4
                    spacing: Theme.unit
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.unit * 4
                        ShellIcon { text: "tune"; color: Theme.accent; iconSize: 28 }
                        Label { text: "Settings"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    }
                    Repeater {
                        model: root.pages
                        ShellButton {
                            required property var modelData
                            Layout.fillWidth: true
                            symbol: modelData.icon
                            text: modelData.label
                            primary: ShellSettings.settingsSection === modelData.id
                            onClicked: root.selectPage(modelData.id)
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Label { text: "Esc to close"; color: Theme.disabled; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption; Layout.alignment: Qt.AlignHCenter }
                }
            }
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.separator }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.pageIndex

                SettingsPage {
                    title: "Network"; subtitle: "Wireless and wired connectivity"
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: root.wifiDevice ? "Wi-Fi" : "No Wi-Fi adapter"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; Layout.fillWidth: true }
                        ShellToggle { checked: Networking.wifiEnabled; enabled: Networking.wifiHardwareEnabled; onToggled: Networking.wifiEnabled = checked }
                    }
                    Repeater {
                        model: root.wifiNetworks
                        SettingRow {
                            required property var modelData
                            symbol: modelData.connected ? "wifi" : "network_wifi"
                            title: modelData.name
                            description: modelData.connected ? "Connected" : `${Math.round(modelData.signalStrength * 100)}% signal`
                            ShellButton { text: modelData.connected ? "Disconnect" : "Connect"; primary: modelData.connected; onClicked: root.activateNetwork(modelData) }
                        }
                    }
                    Rectangle {
                        visible: root.passwordNetwork !== null
                        Layout.fillWidth: true; implicitHeight: 82 * Theme.scale; radius: Theme.radiusMedium; color: Theme.surfaceRaised
                        RowLayout {
                            anchors.fill: parent; anchors.margins: Theme.unit * 3
                            ShellTextField { id: wifiPassword; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: `Password for ${root.passwordNetwork?.name || "network"}` }
                            ShellButton { text: "Cancel"; onClicked: { wifiPassword.text = ""; root.passwordNetwork = null } }
                            ShellButton { text: "Connect"; primary: true; enabled: wifiPassword.text.length > 0; onClicked: { root.passwordNetwork.connectWithPsk(wifiPassword.text); wifiPassword.text = ""; root.passwordNetwork = null } }
                        }
                    }
                    Label { visible: root.statusMessage !== ""; text: root.statusMessage; color: Theme.danger; font.family: Theme.fontFamily }
                }

                SettingsPage {
                    title: "Bluetooth"; subtitle: "Nearby and paired devices"
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: root.bluetoothAdapter?.discovering ? "Scanning for devices..." : root.bluetoothAdapter ? "Bluetooth adapter" : "No Bluetooth adapter"; color: Theme.muted; font.family: Theme.fontFamily; Layout.fillWidth: true }
                        ShellToggle { checked: root.bluetoothAdapter?.enabled ?? false; enabled: root.bluetoothAdapter !== null; onToggled: root.bluetoothAdapter.enabled = checked }
                    }
                    Repeater {
                        model: root.bluetoothAdapter?.devices.values ?? []
                        SettingRow {
                            required property var modelData
                            symbol: modelData.connected ? "bluetooth_connected" : "bluetooth"
                            title: modelData.name || modelData.deviceName || modelData.address
                            description: modelData.connected ? `Connected${modelData.batteryAvailable ? `, ${Math.round(modelData.battery * 100)}% battery` : ""}` : modelData.paired ? "Paired" : "New device"
                            ShellButton { text: modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"; primary: modelData.connected; onClicked: modelData.connected ? modelData.disconnect() : modelData.paired ? modelData.connect() : root.shell.bluetoothAgent.pair(modelData) }
                        }
                    }
                }

                SettingsPage {
                    title: "Audio"; subtitle: "PipeWire output, input and application streams"
                    SettingRow {
                        symbol: Pipewire.defaultAudioSink?.audio.muted ? "volume_off" : "volume_up"
                        title: Pipewire.defaultAudioSink?.description || "Default output"
                        description: `${Math.round((Pipewire.defaultAudioSink?.audio.volume ?? 0) * 100)}% volume`
                        ShellButton { symbol: Pipewire.defaultAudioSink?.audio.muted ? "volume_off" : "volume_up"; text: ""; enabled: Pipewire.defaultAudioSink !== null; onClicked: Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted }
                    }
                    ShellSlider { Layout.fillWidth: true; from: 0; to: 1.5; value: Pipewire.defaultAudioSink?.audio.volume ?? 0; enabled: Pipewire.defaultAudioSink !== null; onMoved: Pipewire.defaultAudioSink.audio.volume = value }
                    SettingRow {
                        symbol: Pipewire.defaultAudioSource?.audio.muted ? "mic_off" : "mic"
                        title: Pipewire.defaultAudioSource?.description || "Default microphone"
                        description: `${Math.round((Pipewire.defaultAudioSource?.audio.volume ?? 0) * 100)}% input level`
                        ShellButton { symbol: Pipewire.defaultAudioSource?.audio.muted ? "mic_off" : "mic"; text: ""; enabled: Pipewire.defaultAudioSource !== null; onClicked: Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted }
                    }
                    ShellSlider { Layout.fillWidth: true; from: 0; to: 1.5; value: Pipewire.defaultAudioSource?.audio.volume ?? 0; enabled: Pipewire.defaultAudioSource !== null; onMoved: Pipewire.defaultAudioSource.audio.volume = value }
                    Label { text: "Outputs"; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
                    Repeater {
                        model: Pipewire.nodes.values.filter(node => node.audio && node.isSink && !node.isStream)
                        SettingRow {
                            required property var modelData
                            symbol: "speaker"; title: modelData.description || modelData.nickname || modelData.name
                            description: modelData === Pipewire.defaultAudioSink ? "Current output" : "Audio output"
                            ShellButton { text: modelData === Pipewire.defaultAudioSink ? "Selected" : "Use"; primary: modelData === Pipewire.defaultAudioSink; onClicked: Pipewire.preferredDefaultAudioSink = modelData }
                        }
                    }
                    Label { text: "Application streams"; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
                    Repeater {
                        model: Pipewire.nodes.values.filter(node => node.audio && node.isStream)
                        SettingRow { required property var modelData; symbol: "graphic_eq"; title: modelData.description || modelData.nickname || modelData.name; description: `${Math.round(modelData.audio.volume * 100)}%`; ShellToggle { checked: !modelData.audio.muted; onToggled: modelData.audio.muted = !checked } }
                    }
                }

                SettingsPage {
                    title: "Displays"; subtitle: "Niri output scale is restored when the shell starts"
                    Rectangle {
                        visible: root.pendingOutputChange !== null
                        Layout.fillWidth: true
                        implicitHeight: 64 * Theme.scale
                        radius: Theme.radiusMedium
                        color: Theme.accentMuted
                        RowLayout {
                            anchors.fill: parent; anchors.margins: Theme.unit * 3
                            Label { text: "Keep this display scale? It will revert in 15 seconds."; color: Theme.foreground; font.family: Theme.fontFamily; Layout.fillWidth: true }
                            ShellButton { text: "Revert"; onClicked: root.revertOutputChange() }
                            ShellButton { text: "Keep"; primary: true; onClicked: root.keepOutputChange() }
                        }
                    }
                    Repeater {
                        model: root.outputs
                        SettingRow {
                            required property var modelData
                            symbol: "monitor"; title: modelData.name
                            description: `${modelData.logical?.width || "?"}x${modelData.logical?.height || "?"}, scale ${modelData.logical?.scale || 1}`
                            ShellButton { symbol: "remove"; text: ""; onClicked: root.applyOutputScale(modelData.name, (modelData.logical?.scale || 1) - 0.25) }
                            Label { text: String(modelData.logical?.scale || 1); color: Theme.foreground; font.family: Theme.monoFamily }
                            ShellButton { symbol: "add"; text: ""; onClicked: root.applyOutputScale(modelData.name, (modelData.logical?.scale || 1) + 0.25) }
                        }
                    }
                    SettingRow {
                        symbol: "brightness_6"; title: "Display brightness"; description: "Applies to the built-in display when supported"
                        ShellButton { text: "-5%"; onClicked: Quickshell.execDetached(["brightnessctl", "set", "5%-"]) }
                        ShellButton { text: "+5%"; onClicked: Quickshell.execDetached(["brightnessctl", "set", "5%+"]) }
                    }
                }

                SettingsPage {
                    title: "Power"; subtitle: "Battery status and session actions"
                    SettingRow { symbol: UPower.displayDevice.isLaptopBattery ? "battery_full" : "power"; title: UPower.displayDevice.isLaptopBattery ? `${Math.round(UPower.displayDevice.percentage * 100)}% battery` : "External power"; description: UPower.displayDevice.isLaptopBattery ? (UPower.onBattery ? "Running on battery" : "Charging or fully charged") : "No laptop battery detected" }
                    SettingRow { symbol: "lock"; title: "Lock screen"; description: "Lock this session immediately"; ShellButton { text: "Lock"; onClicked: Quickshell.execDetached(["swaylock", "-f"]) } }
                    SettingRow { symbol: "bedtime"; title: "Suspend"; description: "Suspend the computer"; ShellButton { text: "Suspend"; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) } }
                    SettingRow { symbol: "restart_alt"; title: "Restart"; description: "Restart the computer"; ShellButton { text: "Restart"; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) } }
                    SettingRow { symbol: "power_settings_new"; title: "Power off"; description: "Shut down the computer"; ShellButton { text: "Power off"; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) } }
                }

                SettingsPage {
                    title: "Input"; subtitle: "Keyboard and touchpad configuration from Niri"
                    SettingRow { symbol: "language"; title: "Keyboard layout"; description: root.shell.keyboardLayout; ShellButton { text: "Switch"; onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]) } }
                    SettingRow { symbol: "touch_app"; title: "Touchpad gestures"; description: "Tap to click and natural scrolling are enabled in the shared Niri profile" }
                    SettingRow { symbol: "info"; title: "Portable defaults"; description: "Input defaults remain declarative so Arch and NixOS stay consistent" }
                }

                SettingsPage {
                    title: "Appearance"; subtitle: "Shell colors, scale and motion"
                    Label { text: "Accent color"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLabel; font.weight: Font.DemiBold }
                    RowLayout {
                        spacing: Theme.unit * 3
                        Repeater {
                            model: [{ id: "blue", color: "#8ab4f8" }, { id: "violet", color: "#b4a0ff" }, { id: "cyan", color: "#63d8e8" }, { id: "green", color: "#83d6a2" }, { id: "rose", color: "#f49ab8" }]
                            Button {
                                id: swatch
                                required property var modelData
                                implicitWidth: 46 * Theme.scale; implicitHeight: implicitWidth
                                onClicked: ShellSettings.accentName = modelData.id
                                background: Rectangle { radius: width / 2; color: swatch.modelData.color; border.width: ShellSettings.accentName === swatch.modelData.id ? 4 : 1; border.color: ShellSettings.accentName === swatch.modelData.id ? Theme.foreground : Theme.outline }
                            }
                        }
                    }
                    SettingRow {
                        symbol: "text_fields"; title: "Interface scale"; description: `${Math.round(ShellSettings.interfaceScale * 100)}%`
                        ShellButton { symbol: "remove"; text: ""; onClicked: ShellSettings.interfaceScale = Math.max(0.85, ShellSettings.interfaceScale - 0.05) }
                        ShellButton { symbol: "add"; text: ""; onClicked: ShellSettings.interfaceScale = Math.min(1.3, ShellSettings.interfaceScale + 0.05) }
                    }
                    SettingRow { symbol: "animation"; title: "Reduce motion"; description: "Disable non-essential transitions"; ShellToggle { checked: ShellSettings.reduceMotion; onToggled: ShellSettings.reduceMotion = checked } }
                    SettingRow { symbol: "monitoring"; title: "System monitor widget"; description: "Show the desktop performance widget"; ShellToggle { checked: ShellSettings.monitorVisible; onToggled: ShellSettings.monitorVisible = checked } }
                    SettingRow { symbol: "touch_app"; title: "Monitor click-through"; description: "Let pointer input pass through the desktop widget"; ShellToggle { checked: ShellSettings.monitorClickThrough; onToggled: ShellSettings.monitorClickThrough = checked } }
                }

                SettingsPage {
                    title: "System"; subtitle: "Live information provided by dgop"
                    SettingRow { symbol: "dns"; title: MetricsService.hostname || "Computer"; description: MetricsService.uptime ? `Uptime ${MetricsService.uptime}` : MetricsService.errorMessage }
                    SettingRow { symbol: "memory"; title: `CPU ${MetricsService.cpuUsage.toFixed(0)}%`; description: "Current total processor utilization" }
                    SettingRow { symbol: "developer_board"; title: `Memory ${MetricsService.memoryUsage.toFixed(0)}%`; description: `${MetricsService.memoryUsed || 0} of ${MetricsService.memoryTotal || 0}` }
                    SettingRow { symbol: "hard_drive"; title: `Root disk ${MetricsService.diskUsage.toFixed(0)}%`; description: `${MetricsService.diskUsed || "Unknown"} used of ${MetricsService.diskSize || "unknown"}` }
                    ShellButton { Layout.alignment: Qt.AlignLeft; symbol: "monitoring"; text: "Open performance dashboard"; primary: true; onClicked: root.shell.openModal("monitor") }
                }
            }
        }
    }

    component SettingsPage: Flickable {
        id: page
        required property string title
        required property string subtitle
        default property alias content: pageColumn.data
        contentWidth: width
        contentHeight: pageColumn.implicitHeight + Theme.unit * 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: pageColumn
            width: parent.width - Theme.unit * 14
            x: Theme.unit * 7
            spacing: Theme.unit * 3
            Label { text: page.title; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontDisplay; font.weight: Font.DemiBold; Layout.topMargin: Theme.unit * 7 }
            Label { text: page.subtitle; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody; Layout.bottomMargin: Theme.unit * 3 }
        }
    }

    Keys.onEscapePressed: shell.closeModal()
}
