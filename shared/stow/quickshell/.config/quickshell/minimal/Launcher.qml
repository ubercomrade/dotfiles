pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import "."

Item {
    id: root
    required property var shell
    focus: true
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
    property string pendingPowerAction: ""

    onVisibleEntriesChanged: currentIndex = Math.max(0, Math.min(currentIndex, visibleEntries.length - 1))

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

    function handleEscape(): void {
        if (pendingPowerAction !== "")
            pendingPowerAction = ""
        else if (shell.bluetoothAgent.promptType !== "none")
            shell.bluetoothAgent.cancel()
        else if (section !== "main")
            closeSection()
        else
            shell.closeModal()
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

    function requestPowerAction(action): void {
        if (action === "suspend") {
            Quickshell.execDetached(["systemctl", "suspend"])
            shell.closeModal()
        } else {
            pendingPowerAction = action
        }
    }

    function confirmPowerAction(): void {
        const action = pendingPowerAction
        pendingPowerAction = ""
        if (action === "restart")
            Quickshell.execDetached(["systemctl", "reboot"])
        else if (action === "poweroff")
            Quickshell.execDetached(["systemctl", "poweroff"])
        shell.closeModal()
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
        Accessible.name: `${primaryText}, ${secondaryText}`
        implicitWidth: 150 * Theme.scale
        implicitHeight: 52 * Theme.scale
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
                Layout.preferredWidth: 28 * Theme.scale
                Layout.preferredHeight: 28 * Theme.scale
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

    component BatteryIndicator: Rectangle {
        id: batteryIndicator
        readonly property real level: Math.max(0, Math.min(1, UPower.displayDevice.percentage))
        readonly property color fillColor: level <= 0.15 ? Theme.danger : UPower.onBattery ? Theme.accent : Theme.success

        Accessible.name: qsTr("Battery %1 percent").arg(Math.round(level * 100))
        Layout.preferredWidth: 86 * Theme.scale
        Layout.preferredHeight: 52 * Theme.scale
        radius: Theme.radiusMedium
        color: Theme.surfaceRaised

        RowLayout {
            anchors.centerIn: parent
            spacing: Theme.unit * 2

            Item {
                Layout.preferredWidth: 38 * Theme.scale
                Layout.preferredHeight: 22 * Theme.scale

                Rectangle {
                    id: batteryBody
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34 * Theme.scale
                    height: 22 * Theme.scale
                    radius: 5 * Theme.scale
                    color: "transparent"
                    border.width: 2 * Theme.scale
                    border.color: Theme.muted

                    Rectangle {
                        id: batteryFill
                        x: 4 * Theme.scale
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 8 * Theme.scale
                        height: parent.height - 8 * Theme.scale
                        radius: 2 * Theme.scale
                        color: batteryIndicator.fillColor
                        transform: Scale {
                            origin.x: 0
                            origin.y: batteryFill.height / 2
                            xScale: batteryIndicator.level
                            Behavior on xScale {
                                NumberAnimation { duration: Theme.normal; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    ShellIcon {
                        anchors.centerIn: parent
                        visible: !UPower.onBattery
                        text: "bolt"
                        color: Theme.accentForeground
                        iconSize: 12
                    }
                }

                Rectangle {
                    anchors.left: batteryBody.right
                    anchors.leftMargin: 2 * Theme.scale
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3 * Theme.scale
                    height: 9 * Theme.scale
                    radius: 2 * Theme.scale
                    color: Theme.muted
                }
            }

            Label {
                text: `${Math.round(batteryIndicator.level * 100)}%`
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption
                font.weight: Font.DemiBold
            }
        }
    }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(Theme.launcherWidth, parent.width - Theme.unit * 8)
        height: Math.min(Theme.launcherHeight, parent.height - Theme.unit * 8)
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

                BatteryIndicator {
                    visible: UPower.displayDevice.isLaptopBattery
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
                    Layout.preferredWidth: Theme.iconButtonSize
                    symbol: "bedtime"
                    text: ""
                    accessibleName: qsTr("Suspend")
                    ToolTip.visible: hovered
                    ToolTip.text: accessibleName
                    onClicked: root.requestPowerAction("suspend")
                }
                ShellButton {
                    Layout.preferredWidth: Theme.iconButtonSize
                    symbol: "restart_alt"
                    text: ""
                    accessibleName: qsTr("Restart")
                    ToolTip.visible: hovered
                    ToolTip.text: accessibleName
                    onClicked: root.requestPowerAction("restart")
                }
                ShellButton {
                    Layout.preferredWidth: Theme.iconButtonSize
                    symbol: "power_settings_new"
                    text: ""
                    danger: true
                    accessibleName: qsTr("Power off")
                    ToolTip.visible: hovered
                    ToolTip.text: accessibleName
                    onClicked: root.requestPowerAction("poweroff")
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
                                border.width: modeButton.activeFocus ? 2 : 0
                                border.color: Theme.accent
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Label { text: "Tab switches modes"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption }
                }

                ShellTextField {
                    id: query
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.controlHeight
                    placeholderText: root.mode === "apps" ? "Search applications" : root.mode === "run" ? "Run command" : "Search clipboard history"
                    selectByMouse: true
                    onTextChanged: root.currentIndex = 0
                    onAccepted: root.activate()
                    Component.onCompleted: forceActiveFocus()
                    Keys.onEscapePressed: root.handleEscape()
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
                        height: Theme.rowHeight
                        highlighted: root.currentIndex === index
                        flat: true
                        onClicked: {
                            root.currentIndex = index
                            root.activate()
                        }
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: resultButton.highlighted ? Theme.accentMuted : resultButton.hovered ? Theme.surfaceRaised : "transparent"
                            border.width: resultButton.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Image {
                                source: Quickshell.iconPath(root.mode === "apps" ? modelData.entry.icon : "edit-paste", "application-x-executable")
                                sourceSize.width: Math.round(28 * Theme.scale)
                                sourceSize.height: Math.round(28 * Theme.scale)
                                Layout.preferredWidth: 28 * Theme.scale
                                Layout.preferredHeight: 28 * Theme.scale
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    Layout.fillWidth: true
                                    text: root.mode === "apps" ? modelData.entry.name : modelData
                                    textFormat: Text.PlainText
                                    color: Theme.foreground
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontLabel
                                    elide: Text.ElideRight
                                }
                                Label {
                                    visible: root.mode === "apps" && modelData.entry && (modelData.entry.genericName || modelData.entry.comment)
                                    Layout.fillWidth: true
                                    text: root.mode === "apps" && modelData.entry ? modelData.entry.genericName || modelData.entry.comment : ""
                                    textFormat: Text.PlainText
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
                    ShellButton { text: qsTr("Back"); symbol: "arrow_back"; onClicked: root.closeSection() }
                    Label { text: "Wi-Fi networks"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    ShellToggle {
                        text: Networking.wifiEnabled ? "On" : "Off"
                        accessibleName: qsTr("Wi-Fi")
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
                        height: Theme.rowHeight
                        flat: true
                        onClicked: root.activateNetwork(modelData)
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: networkButton.hovered ? Theme.surfaceRaised : modelData.connected ? Theme.accentMuted : "transparent"
                            border.width: networkButton.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Rectangle {
                                Layout.preferredWidth: 28 * Theme.scale
                                Layout.preferredHeight: 28 * Theme.scale
                                radius: Theme.radiusSmall
                                color: Theme.accentMuted
                                ShellIcon { anchors.centerIn: parent; text: modelData.connected ? "wifi" : "network_wifi"; color: Theme.accent; iconSize: 19 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { text: modelData.name; textFormat: Text.PlainText; color: Theme.foreground; font.weight: Font.DemiBold }
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
                    Layout.preferredHeight: passwordRow.implicitHeight + Theme.unit * 6
                    radius: Theme.radiusMedium
                    color: Theme.surfaceRaised

                    RowLayout {
                        id: passwordRow
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
                        ShellButton { text: qsTr("Cancel"); onClicked: { wifiPassword.text = ""; root.passwordNetwork = null } }
                        ShellButton { text: qsTr("Connect"); primary: true; enabled: wifiPassword.text.length > 0; onClicked: root.connectWithPassword() }
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
                    ShellButton { text: qsTr("Back"); symbol: "arrow_back"; onClicked: root.closeSection() }
                    Label { text: "Bluetooth devices"; color: Theme.foreground; font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Label { visible: root.bluetoothAdapter?.discovering ?? false; text: "Scanning..."; color: Theme.accent }
                    ShellToggle {
                        text: root.bluetoothAdapter?.enabled ? "On" : "Off"
                        accessibleName: qsTr("Bluetooth")
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
                        height: Theme.rowHeight
                        flat: true
                        enabled: !shell.bluetoothAgent.busy || modelData === shell.bluetoothAgent.pendingDevice
                        onClicked: root.activateBluetoothDevice(modelData)
                        background: Rectangle {
                            radius: Theme.radiusMedium
                            color: deviceButton.hovered ? Theme.surfaceRaised : modelData.connected ? Theme.accentMuted : "transparent"
                            border.width: deviceButton.activeFocus ? 2 : 0
                            border.color: Theme.accent
                        }
                        contentItem: RowLayout {
                            spacing: Theme.unit * 3
                            Rectangle {
                                Layout.preferredWidth: 30 * Theme.scale
                                Layout.preferredHeight: 30 * Theme.scale
                                radius: Theme.radiusSmall
                                color: Theme.accentMuted
                                ShellIcon { anchors.centerIn: parent; text: modelData.connected ? "bluetooth_connected" : "bluetooth"; color: Theme.accent; iconSize: 19 }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label { text: modelData.name || modelData.deviceName || modelData.address; textFormat: Text.PlainText; color: Theme.foreground; font.weight: Font.DemiBold }
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
            visible: root.pendingPowerAction !== ""
            focus: visible
            color: Theme.scrim
            z: 20

            onVisibleChanged: {
                if (visible)
                    Qt.callLater(cancelPowerButton.forceActiveFocus)
            }

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(440 * Theme.scale, parent.width - Theme.unit * 12)
                implicitHeight: powerConfirmColumn.implicitHeight + Theme.unit * 10
                radius: Theme.radiusLarge
                color: Theme.surfaceRaised
                border.width: 1
                border.color: Theme.outline

                ColumnLayout {
                    id: powerConfirmColumn
                    anchors.fill: parent
                    anchors.margins: Theme.unit * 5
                    spacing: Theme.unit * 3

                    Label {
                        text: root.pendingPowerAction === "restart" ? qsTr("Restart computer?") : qsTr("Power off computer?")
                        color: Theme.foreground
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("Unsaved work may be lost.")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontBody
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        ShellButton { id: cancelPowerButton; text: qsTr("Cancel"); onClicked: root.pendingPowerAction = "" }
                        ShellButton { text: root.pendingPowerAction === "restart" ? qsTr("Restart") : qsTr("Power off"); danger: true; onClicked: root.confirmPowerAction() }
                    }
                }
            }
        }

        Rectangle {
            id: bluetoothPrompt
            anchors.fill: parent
            visible: shell.bluetoothAgent.promptType !== "none"
            focus: visible
            color: Theme.scrim
            z: 20

            onVisibleChanged: {
                if (!visible)
                    return
                if (bluetoothCode.visible)
                    Qt.callLater(bluetoothCode.forceActiveFocus)
                else if (continueButton.visible)
                    Qt.callLater(continueButton.forceActiveFocus)
                else
                    Qt.callLater(cancelBluetoothButton.forceActiveFocus)
            }

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(440 * Theme.scale, parent.width - Theme.unit * 12)
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
                        ShellButton { id: cancelBluetoothButton; text: qsTr("Cancel"); onClicked: { bluetoothCode.text = ""; shell.bluetoothAgent.cancel() } }
                        ShellButton {
                            id: continueButton
                            text: "Continue"
                            primary: true
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

    Keys.onEscapePressed: root.handleEscape()
}
