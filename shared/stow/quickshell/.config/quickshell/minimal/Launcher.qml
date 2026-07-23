import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Item {
    id: root
    required property var shell
    property string section: "main"
    property string mode: "apps"
    property int currentIndex: 0
    property var clipboardEntries: []
    property var appEntries: shell.applicationResults(query.text)
    property var visibleEntries: mode === "apps" ? appEntries : mode === "clipboard" ? clipboardEntries.filter(entry => entry.toLowerCase().includes(query.text.toLowerCase())) : []
    property var wifiDevice: Networking.devices.values.find(device => device.type === DeviceType.Wifi) || null
    property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.slice().sort((left, right) => Number(right.connected) - Number(left.connected) || right.signalStrength - left.signalStrength || left.name.localeCompare(right.name)) : []
    property var connectedNetwork: wifiNetworks.find(network => network.connected) || null
    property var passwordNetwork: null
    property var bluetoothAdapter: Bluetooth.defaultAdapter
    property var bluetoothDevices: bluetoothAdapter ? bluetoothAdapter.devices.values.slice().sort((left, right) => Number(right.connected) - Number(left.connected) || Number(right.paired) - Number(left.paired) || (left.name || left.deviceName).localeCompare(right.name || right.deviceName)) : []
    property int connectedBluetoothDevices: bluetoothDevices.filter(device => device.connected).length
    property string statusMessage: ""

    function selectOffset(offset): void {
        if (visibleEntries.length === 0)
            return
        currentIndex = (currentIndex + offset + visibleEntries.length) % visibleEntries.length
        results.positionViewAtIndex(currentIndex, ListView.Contain)
    }

    function activate(): void {
        if (mode === "apps")
            shell.launch(appEntries[currentIndex]?.entry)
        else if (mode === "run" && query.text.trim())
            shell.runCommand(query.text)
        else if (mode === "clipboard")
            shell.copyHistory(visibleEntries[currentIndex])
    }

    function setMode(nextMode): void {
        section = "main"
        mode = nextMode
        currentIndex = 0
        query.forceActiveFocus()
        if (nextMode === "clipboard")
            clipboardProcess.running = true
    }

    function openSection(nextSection): void {
        section = nextSection
        statusMessage = ""
        passwordNetwork = null
        wifiPassword.text = ""
    }

    function closeSection(): void {
        section = "main"
        statusMessage = ""
        passwordNetwork = null
        wifiPassword.text = ""
        query.forceActiveFocus()
    }

    function supportsPsk(network): bool {
        return network.security === WifiSecurityType.Sae || network.security === WifiSecurityType.Wpa2Psk || network.security === WifiSecurityType.WpaPsk
    }

    function activateNetwork(network): void {
        statusMessage = ""
        if (network.connected) {
            network.disconnect()
        } else if (network.known || network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe) {
            network.connect()
        } else if (supportsPsk(network)) {
            passwordNetwork = network
            wifiPassword.text = ""
            wifiPassword.forceActiveFocus()
        } else {
            statusMessage = "This network security type is not supported by the launcher"
        }
    }

    function connectWithPassword(): void {
        if (!passwordNetwork || !wifiPassword.text)
            return
        passwordNetwork.connectWithPsk(wifiPassword.text)
        wifiPassword.text = ""
        passwordNetwork = null
    }

    function activateBluetoothDevice(device): void {
        statusMessage = ""
        if (device.connected)
            device.disconnect()
        else if (device.paired)
            device.connect()
        else
            shell.bluetoothAgent.pair(device)
    }

    Process {
        id: clipboardProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.clipboardEntries = text.trim() ? text.trim().split("\n") : []
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.section === "wifi" && Networking.wifiEnabled
        when: root.wifiDevice !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: root.bluetoothAdapter
        property: "discovering"
        value: root.section === "bluetooth" && root.bluetoothAdapter?.enabled
        when: root.bluetoothAdapter !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    component StatusButton: Button {
        id: control
        property string iconName: ""
        property string primaryText: ""
        property string secondaryText: ""
        implicitWidth: 150
        implicitHeight: 52
        padding: Theme.unit * 2

        background: Rectangle {
            radius: Theme.radiusMedium
            color: control.down ? Theme.accentMuted : control.hovered ? Theme.surfaceHover : Theme.surfaceRaised
            border.width: 1
            border.color: control.activeFocus ? Theme.accent : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        contentItem: RowLayout {
            spacing: Theme.unit * 2
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Theme.radiusSmall
                color: Theme.accentMuted
                ShellIcon {
                    anchors.centerIn: parent
                    text: control.iconName
                    color: Theme.accent
                    iconSize: 20
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label {
                    Layout.fillWidth: true
                    text: control.primaryText
                    color: Theme.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: control.secondaryText
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption
                    elide: Text.ElideRight
                }
            }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(760, parent.width - Theme.unit * 8)
        height: Math.min(600, parent.height - Theme.unit * 8)
        radius: Theme.radiusLarge
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        clip: true

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.unit * 6
            spacing: Theme.unit * 4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.unit * 3

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontDisplay
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                    }
                }

                Rectangle {
                    visible: UPower.displayDevice.isLaptopBattery
                    Layout.preferredWidth: 78
                    Layout.preferredHeight: 52
                    radius: Theme.radiusMedium
                    color: Theme.surfaceRaised

                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                            color: Theme.foreground
                            font.weight: Font.DemiBold
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Battery"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                }

                StatusButton {
                    iconName: Networking.wifiEnabled ? "wifi" : "wifi_off"
                    primaryText: root.connectedNetwork?.name || (Networking.wifiEnabled ? "Wi-Fi" : "Wi-Fi off")
                    secondaryText: root.connectedNetwork ? "Connected" : "Networks"
                    onClicked: root.openSection(root.section === "wifi" ? "main" : "wifi")
                }
                StatusButton {
                    iconName: root.bluetoothAdapter?.enabled ? "bluetooth" : "bluetooth_disabled"
                    primaryText: "Bluetooth"
                    secondaryText: !root.bluetoothAdapter ? "Unavailable" : root.connectedBluetoothDevices ? `${root.connectedBluetoothDevices} connected` : root.bluetoothAdapter.enabled ? "Available" : "Off"
                    onClicked: root.openSection(root.section === "bluetooth" ? "main" : "bluetooth")
                }
                ShellButton {
                    Layout.preferredWidth: 52 * Theme.scale
                    symbol: "settings"
                    text: ""
                    onClicked: root.shell.openModal("settings")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.outline
            }

            ColumnLayout {
                visible: root.section === "main"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.unit * 2

                    Repeater {
                        model: [{ id: "apps", label: "Apps" }, { id: "run", label: "Run" }, { id: "clipboard", label: "Clipboard" }]
                        delegate: Button {
                            id: modeButton
                            required property var modelData
                            text: modelData.label
                            checkable: true
                            checked: root.mode === modelData.id
                            flat: true
                            onClicked: root.setMode(modelData.id)
                            background: Rectangle {
                                radius: Theme.radiusPill
                                color: modeButton.checked ? Theme.accentMuted : modeButton.hovered ? Theme.surfaceRaised : "transparent"
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Label { text: "Tab switches modes"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                }

                ShellTextField {
                    id: query
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    placeholderText: root.mode === "apps" ? "Search applications" : root.mode === "run" ? "Run command" : "Search clipboard history"
                    selectByMouse: true
                    onTextChanged: root.currentIndex = 0
                    onAccepted: root.activate()
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: shell.closeModal()
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Tab) {
                            root.setMode(root.mode === "apps" ? "run" : root.mode === "run" ? "clipboard" : "apps")
                            event.accepted = true
                        } else if (event.key === Qt.Key_Backtab) {
                            root.setMode(root.mode === "apps" ? "clipboard" : root.mode === "run" ? "apps" : "run")
                            event.accepted = true
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier)) {
                            root.selectOffset(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier)) {
                            root.selectOffset(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Home) {
                            root.currentIndex = 0
                            event.accepted = true
                        } else if (event.key === Qt.Key_End) {
                            root.currentIndex = Math.max(0, root.visibleEntries.length - 1)
                            event.accepted = true
                        }
                    }
                }

                Label {
                    visible: root.mode === "run"
                    Layout.fillWidth: true
                    text: "Commands run through /bin/sh. Review the command before pressing Enter."
                    color: Theme.muted
                    wrapMode: Text.Wrap
                }

                ListView {
                    id: results
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.unit
                    model: root.mode === "run" ? [] : root.visibleEntries

                    delegate: Button {
                        id: resultButton
                        required property var modelData
                        required property int index
                        width: ListView.view.width
                        height: 58
                        highlighted: root.currentIndex === index
                        flat: true
                        onClicked: {
                            root.currentIndex = index
                            root.activate()
                        }
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: resultButton.highlighted ? Theme.accentMuted : resultButton.hovered ? Theme.surfaceRaised : "transparent"
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Image {
                                source: Quickshell.iconPath(root.mode === "apps" ? modelData.entry.icon : "edit-paste", "application-x-executable")
                                sourceSize.width: 28
                                sourceSize.height: 28
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    Layout.fillWidth: true
                                    text: root.mode === "apps" ? modelData.entry.name : modelData
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                    elide: Text.ElideRight
                                }
                                Label {
                                    visible: root.mode === "apps" && (modelData.entry.genericName || modelData.entry.comment)
                                    Layout.fillWidth: true
                                    text: modelData.entry.genericName || modelData.entry.comment
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        visible: root.mode !== "run" && root.visibleEntries.length === 0
                        text: root.mode === "clipboard" ? "Clipboard history is empty" : "No applications found"
                        color: Theme.muted
                    }
                }
            }

            ColumnLayout {
                visible: root.section === "wifi"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    Button { text: "Back"; flat: true; onClicked: root.closeSection() }
                    Label { text: "Wi-Fi networks"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    ShellToggle {
                        text: Networking.wifiEnabled ? "On" : "Off"
                        checked: Networking.wifiEnabled
                        enabled: Networking.wifiHardwareEnabled
                        onToggled: Networking.wifiEnabled = checked
                    }
                }

                Label {
                    visible: !root.wifiDevice
                    Layout.fillWidth: true
                    text: "No Wi-Fi adapter available"
                    color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.wifiDevice && Networking.wifiEnabled
                    clip: true
                    spacing: Theme.unit
                    model: root.wifiNetworks

                    delegate: Button {
                        id: networkButton
                        required property var modelData
                        width: ListView.view.width
                        height: 58
                        flat: true
                        onClicked: root.activateNetwork(modelData)
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: networkButton.hovered ? Theme.surfaceRaised : modelData.connected ? Theme.accentMuted : "transparent"
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: Theme.radiusSmall
                                color: Theme.accentMuted
                                ShellIcon { anchors.centerIn: parent; text: modelData.connected ? "wifi" : "network_wifi"; color: Theme.accent; iconSize: 19 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { text: modelData.name; color: Theme.foreground; font.weight: Font.DemiBold }
                                Label {
                                    text: modelData.connected ? "Connected" : modelData.stateChanging ? "Connecting..." : modelData.known ? "Saved network" : modelData.security === WifiSecurityType.Open || modelData.security === WifiSecurityType.Owe ? "Open network" : root.supportsPsk(modelData) ? "Password required" : "Unsupported security"
                                    color: modelData.connected ? Theme.success : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                }
                            }
                            Label { text: `${Math.round(modelData.signalStrength * 100)}%`; color: Theme.muted }
                            Label { text: modelData.connected ? "Disconnect" : "Connect"; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                        }
                        Connections {
                            target: modelData
                            function onConnectionFailed(reason): void { root.statusMessage = `Connection failed: ${ConnectionFailReason.toString(reason)}` }
                        }
                    }
                }

                Rectangle {
                    visible: root.passwordNetwork !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92
                    radius: Theme.radiusMedium
                    color: Theme.surfaceRaised

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.unit * 3
                        spacing: Theme.unit * 2
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: `Password for ${root.passwordNetwork?.name || "network"}`; color: Theme.foreground }
                            ShellTextField {
                                id: wifiPassword
                                Layout.fillWidth: true
                                echoMode: TextInput.Password
                                placeholderText: "Network password"
                                onAccepted: root.connectWithPassword()
                            }
                        }
                        Button { text: "Cancel"; onClicked: { wifiPassword.text = ""; root.passwordNetwork = null } }
                        Button { text: "Connect"; enabled: wifiPassword.text.length > 0; onClicked: root.connectWithPassword() }
                    }
                }
                Label { visible: root.statusMessage !== ""; text: root.statusMessage; color: Theme.danger; Layout.fillWidth: true; wrapMode: Text.Wrap }
            }

            ColumnLayout {
                visible: root.section === "bluetooth"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.unit * 3

                RowLayout {
                    Layout.fillWidth: true
                    Button { text: "Back"; flat: true; onClicked: root.closeSection() }
                    Label { text: "Bluetooth devices"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Label { visible: root.bluetoothAdapter?.discovering ?? false; text: "Scanning..."; color: Theme.accent }
                    ShellToggle {
                        text: root.bluetoothAdapter?.enabled ? "On" : "Off"
                        checked: root.bluetoothAdapter?.enabled ?? false
                        enabled: root.bluetoothAdapter !== null
                        onToggled: root.bluetoothAdapter.enabled = checked
                    }
                }

                Label {
                    visible: !root.bluetoothAdapter
                    Layout.fillWidth: true
                    text: "No Bluetooth adapter available"
                    color: Theme.muted
                    horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.bluetoothAdapter?.enabled ?? false
                    clip: true
                    spacing: Theme.unit
                    model: root.bluetoothDevices

                    delegate: Button {
                        id: deviceButton
                        required property var modelData
                        width: ListView.view.width
                        height: 60
                        flat: true
                        enabled: !shell.bluetoothAgent.busy || modelData === shell.bluetoothAgent.pendingDevice
                        onClicked: root.activateBluetoothDevice(modelData)
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: deviceButton.hovered ? Theme.surfaceRaised : modelData.connected ? Theme.accentMuted : "transparent"
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Rectangle {
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                radius: Theme.radiusSmall
                                color: Theme.accentMuted
                                ShellIcon { anchors.centerIn: parent; text: modelData.connected ? "bluetooth_connected" : "bluetooth"; color: Theme.accent; iconSize: 19 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { text: modelData.name || modelData.deviceName || modelData.address; color: Theme.foreground; font.weight: Font.DemiBold }
                                Label {
                                    text: modelData.connected ? "Connected" : modelData.pairing ? "Pairing..." : modelData.state === BluetoothDeviceState.Connecting ? "Connecting..." : modelData.paired ? "Paired" : "New device"
                                    color: modelData.connected ? Theme.success : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption
                                }
                            }
                            Label {
                                visible: modelData.batteryAvailable
                                text: `${Math.round(modelData.battery * 100)}%`
                                color: Theme.muted
                            }
                            Label { text: modelData.connected ? "Disconnect" : modelData.paired ? "Connect" : "Pair"; color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                        }
                    }
                }
                Label {
                    visible: shell.bluetoothAgent.statusMessage !== ""
                    text: shell.bluetoothAgent.statusMessage
                    color: shell.bluetoothAgent.statusMessage.includes("failed") || shell.bluetoothAgent.statusMessage.includes("stopped") ? Theme.danger : Theme.muted
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: shell.bluetoothAgent.promptType !== "none"
            color: Theme.scrim
            z: 20

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(440, parent.width - Theme.unit * 12)
                implicitHeight: promptColumn.implicitHeight + Theme.unit * 10
                radius: Theme.radiusLarge
                color: Theme.surfaceRaised
                border.width: 1
                border.color: Theme.outline

                ColumnLayout {
                    id: promptColumn
                    anchors.fill: parent
                    anchors.margins: Theme.unit * 5
                    spacing: Theme.unit * 3

                    Label { text: "Bluetooth pairing"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Label {
                        Layout.fillWidth: true
                        text: shell.bluetoothAgent.promptType === "confirm" ? `Confirm that ${shell.bluetoothAgent.promptValue} is displayed on the device.` : shell.bluetoothAgent.promptType === "display" ? `Type ${shell.bluetoothAgent.promptValue} on the Bluetooth device, then press Enter there.` : shell.bluetoothAgent.promptType === "authorize" ? `Authorize Bluetooth service ${shell.bluetoothAgent.promptValue}?` : "Enter the code shown by the Bluetooth device."
                        color: Theme.muted
                        wrapMode: Text.Wrap
                    }
                    ShellTextField {
                        id: bluetoothCode
                        visible: shell.bluetoothAgent.promptType === "pin" || shell.bluetoothAgent.promptType === "passkey"
                        Layout.fillWidth: true
                        placeholderText: shell.bluetoothAgent.promptType === "pin" ? "PIN code" : "Passkey"
                        inputMethodHints: shell.bluetoothAgent.promptType === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                        onAccepted: {
                            shell.bluetoothAgent.answer(text)
                            text = ""
                        }
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        Button { text: "Cancel"; onClicked: { bluetoothCode.text = ""; shell.bluetoothAgent.cancel() } }
                        Button {
                            text: "Continue"
                            visible: shell.bluetoothAgent.promptType !== "display"
                            enabled: shell.bluetoothAgent.promptType === "confirm" || shell.bluetoothAgent.promptType === "authorize" || bluetoothCode.text.length > 0
                            onClicked: {
                                shell.bluetoothAgent.answer(shell.bluetoothAgent.promptType === "confirm" || shell.bluetoothAgent.promptType === "authorize" ? "yes" : bluetoothCode.text)
                                bluetoothCode.text = ""
                            }
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: {
        if (shell.bluetoothAgent.promptType !== "none")
            shell.bluetoothAgent.cancel()
        else if (root.section !== "main")
            root.closeSection()
        else
            shell.closeModal()
    }
}
